using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ClienteRentaTica.Pages;

[AttributeUsage(AttributeTargets.Property)]
public sealed class PositiveMoneyAttribute : ValidationAttribute
{
    public override bool IsValid(object? value)
    {
        return value is decimal amount && amount >= 0.01m && amount <= 99999999.99m &&
               decimal.Round(amount, 2) == amount;
    }
}

public sealed class IndexModel(IHttpClientFactory httpClientFactory) : PageModel
{
    private const string TokenKey = "rentatica-api-token";
    private const string EmailKey = "rentatica-user-email";
    private const string NameKey = "rentatica-user-name";
    private const string RoleKey = "rentatica-user-role";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    [BindProperty]
    public LoginInput Input { get; set; } = new();

    [BindProperty]
    public string? Estado { get; set; } = "Disponible";

    [BindProperty]
    public ReservationInput Reserva { get; set; } = new();



    public List<CustomerOption> Clientes { get; private set; } = [];
    public List<EquipmentOption> EquiposDisponibles { get; private set; } = [];
    public List<ReservationSummary> Reservas { get; private set; } = [];

    [BindProperty]
    public string FiltroEstadoReserva { get; set; } = "";

    public List<ReservationSummary> ReservasVisibles => string.IsNullOrWhiteSpace(FiltroEstadoReserva)
        ? Reservas
        : Reservas.Where(reserva => reserva.Estado.Equals(FiltroEstadoReserva, StringComparison.OrdinalIgnoreCase)).ToList();

    public bool IsAuthenticated => !string.IsNullOrWhiteSpace(HttpContext.Session.GetString(TokenKey));
    public string DisplayEmail => HttpContext.Session.GetString(EmailKey) ?? "";
    public string DisplayName => HttpContext.Session.GetString(NameKey) ?? DisplayEmail;
    public string DisplayRole => HttpContext.Session.GetString(RoleKey) ?? "";
    public string? StatusMessage { get; private set; }
    public string? ErrorMessage { get; private set; }
    public string? ResponseJson { get; private set; }

    public async Task OnGetAsync()
    {
        SetFormDefaults();
        await LoadReferenceDataAsync();
    }

    public async Task<IActionResult> OnPostLoginAsync()
    {
        if (HasErrorsFor(nameof(Input)))
        {
            ErrorMessage = GetValidationErrors(nameof(Input));
            return Page();
        }

        try
        {
            var client = httpClientFactory.CreateClient("RentaTicaApi");
            using var response = await client.PostAsJsonAsync(
                "api/auth/login",
                new { email = Input.Email.Trim(), password = Input.Password });

            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                ErrorMessage = ReadApiError(body) ?? "El API rechazó el inicio de sesión.";
                return Page();
            }

            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;
            if (!root.TryGetProperty("token", out var tokenElement) ||
                string.IsNullOrWhiteSpace(tokenElement.GetString()))
            {
                ErrorMessage = "La respuesta del API no contiene un token.";
                return Page();
            }

            HttpContext.Session.SetString(TokenKey, tokenElement.GetString()!);
            var user = root.TryGetProperty("usuario", out var userElement) ? userElement : default;
            HttpContext.Session.SetString(EmailKey, ReadProperty(user, "email") ?? Input.Email.Trim());
            HttpContext.Session.SetString(NameKey, ReadProperty(user, "nombre_completo") ?? Input.Email.Trim());
            HttpContext.Session.SetString(RoleKey, ReadProperty(user, "rol") ?? "");

            Input.Password = "";
            ModelState.Clear();
            StatusMessage = "Sesión iniciada. Ya puedes crear una reserva de prueba.";
            SetFormDefaults();
            await LoadReferenceDataAsync();
            return Page();
        }
        catch (HttpRequestException)
        {
            ErrorMessage = "No se pudo contactar al API. Confirma que esté activo en http://localhost:3000.";
            return Page();
        }
        catch (JsonException)
        {
            ErrorMessage = "El API respondió con un formato JSON inesperado.";
            return Page();
        }
    }

    public async Task<IActionResult> OnPostEquiposAsync()
    {
        var estado = Uri.EscapeDataString(Estado ?? "Disponible");
        return await GetProtectedPageAsync("api/equipos?estado=" + estado, "Consulta de equipos completada.");
    }

    public async Task<IActionResult> OnPostReporteInventarioAsync()
    {
        return await GetProtectedPageAsync("api/reportes/inventario", "Reporte de inventario completado.");
    }

    public async Task<IActionResult> OnPostCrearReservaAsync()
    {
        if (HasErrorsFor(nameof(Reserva)))
        {
            ErrorMessage = GetValidationErrors(nameof(Reserva));
            await LoadReferenceDataAsync();
            return Page();
        }

        var payload = new
        {
            cliente_id = Reserva.ClienteId,
            equipo_ids = new[] { Reserva.EquipoId },
            tipo_reserva = Reserva.TipoReserva,
            fecha_inicio = Reserva.FechaInicio,
            fecha_fin = Reserva.FechaFin
        };
        var result = await SendProtectedAsync(HttpMethod.Post, "api/reservas", payload);
        if (result is null)
        {
            await LoadReferenceDataAsync();
            return Page();
        }

        using var created = JsonDocument.Parse(result);
        return RedirectToPage("/Reserva", new { id = created.RootElement.GetProperty("reserva_id").GetInt32() });
    }
    public async Task<IActionResult> OnPostFiltrarReservasAsync()
    {
        await LoadReferenceDataAsync();
        return Page();
    }

    public IActionResult OnPostLogout()
    {
        HttpContext.Session.Clear();
        StatusMessage = "La sesión se cerró.";
        return Page();
    }

    private async Task<IActionResult> GetProtectedPageAsync(string path, string successMessage)
    {
        var body = await SendProtectedAsync(HttpMethod.Get, path);
        if (body is not null)
        {
            ResponseJson = FormatJson(body);
            StatusMessage = successMessage;
        }
        await LoadReferenceDataAsync();
        return Page();
    }

    private async Task<string?> SendProtectedAsync(HttpMethod method, string path, object? payload = null)
    {
        var token = HttpContext.Session.GetString(TokenKey);
        if (string.IsNullOrWhiteSpace(token))
        {
            ErrorMessage = "Inicia sesión antes de usar las operaciones.";
            return null;
        }

        try
        {
            var client = httpClientFactory.CreateClient("RentaTicaApi");
            using var request = new HttpRequestMessage(method, path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            if (payload is not null) request.Content = JsonContent.Create(payload);
            using var response = await client.SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();

            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                HttpContext.Session.Clear();
                ErrorMessage = "La sesión venció o el token ya no es válido. Inicia sesión otra vez.";
                return null;
            }
            if (!response.IsSuccessStatusCode)
            {
                ErrorMessage = ReadApiError(body) ?? "El API respondió con HTTP " + (int)response.StatusCode + ".";
                return null;
            }
            return body;
        }
        catch (HttpRequestException)
        {
            ErrorMessage = "No se pudo contactar al API. Confirma que esté activo en http://localhost:3000.";
            return null;
        }
        catch (JsonException)
        {
            ErrorMessage = "El API respondió con un formato JSON inesperado.";
            return null;
        }
    }

    private async Task LoadReferenceDataAsync()
    {
        Clientes = [];
        EquiposDisponibles = [];
        Reservas = [];
        if (!IsAuthenticated) return;

        Clientes = await LoadListAsync<CustomerOption>("api/clientes");
        EquiposDisponibles = await LoadListAsync<EquipmentOption>("api/equipos?estado=Disponible");
        Reservas = await LoadListAsync<ReservationSummary>("api/reservas");
    }

    private async Task<List<T>> LoadListAsync<T>(string path)
    {
        var body = await SendProtectedAsync(HttpMethod.Get, path);
        if (body is null) return [];
        try
        {
            using var document = JsonDocument.Parse(body);
            if (!document.RootElement.TryGetProperty("datos", out var data) || data.ValueKind != JsonValueKind.Array)
                return [];
            return JsonSerializer.Deserialize<List<T>>(data.GetRawText(), JsonOptions) ?? [];
        }
        catch (JsonException)
        {
            ErrorMessage = "No se pudieron leer los catálogos del API.";
            return [];
        }
    }

    private bool HasErrorsFor(string prefix)
    {
        return ModelState.Any(entry =>
            (entry.Key.Equals(prefix, StringComparison.OrdinalIgnoreCase) ||
             entry.Key.StartsWith(prefix + ".", StringComparison.OrdinalIgnoreCase)) &&
            entry.Value?.Errors.Count > 0);
    }

    private string GetValidationErrors(string prefix)
    {
        var errors = ModelState
            .Where(entry => entry.Key.Equals(prefix, StringComparison.OrdinalIgnoreCase) ||
                            entry.Key.StartsWith(prefix + ".", StringComparison.OrdinalIgnoreCase))
            .SelectMany(entry => entry.Value?.Errors.Select(error => error.ErrorMessage) ?? [])
            .Where(message => !string.IsNullOrWhiteSpace(message))
            .Distinct()
            .ToArray();
        return errors.Length > 0 ? string.Join(" ", errors) : "Revisa los datos del formulario e intenta otra vez.";
    }

    private void SetFormDefaults()
    {
        if (Reserva.FechaInicio == default) Reserva.FechaInicio = DateTime.Now.AddMinutes(-1);
        if (Reserva.FechaFin == default) Reserva.FechaFin = DateTime.Now.AddHours(2);
        if (string.IsNullOrWhiteSpace(Reserva.TipoReserva)) Reserva.TipoReserva = "Walk-in";
    }

    private static string? ReadApiError(string body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.TryGetProperty("error", out var error) ? error.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string? ReadProperty(JsonElement element, string property)
    {
        return element.ValueKind == JsonValueKind.Object &&
               element.TryGetProperty(property, out var value) &&
               value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;
    }

    private static string FormatJson(string body)
    {
        using var document = JsonDocument.Parse(body);
        return JsonSerializer.Serialize(document.RootElement, JsonOptions);
    }

    public sealed class LoginInput
    {
        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Escribe un correo válido.")]
        public string Email { get; set; } = "";

        [Required(ErrorMessage = "La contraseña es obligatoria.")]
        [DataType(DataType.Password)]
        public string Password { get; set; } = "";
    }

    public sealed class ReservationInput
    {
        [Range(1, int.MaxValue, ErrorMessage = "Selecciona un cliente.")]
        public int ClienteId { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "Selecciona un equipo disponible.")]
        public int EquipoId { get; set; }

        [Required]
        public string TipoReserva { get; set; } = "Walk-in";

        [Required(ErrorMessage = "Indica la fecha y hora de inicio.")]
        public DateTime FechaInicio { get; set; } = DateTime.Now.AddMinutes(-1);

        [Required(ErrorMessage = "Indica la fecha y hora de fin.")]
        public DateTime FechaFin { get; set; } = DateTime.Now.AddHours(2);
    }

    public sealed class ReservationSummary
    {
        [JsonPropertyName("reserva_id")] public int ReservaId { get; set; }
        [JsonPropertyName("tipo_reserva")] public string TipoReserva { get; set; } = "";
        [JsonPropertyName("estado")] public string Estado { get; set; } = "";
        [JsonPropertyName("fecha_inicio")] public DateTime FechaInicio { get; set; }
        [JsonPropertyName("fecha_fin")] public DateTime FechaFin { get; set; }
        [JsonPropertyName("monto_final")] public decimal MontoFinal { get; set; }
        [JsonPropertyName("cliente")] public string Cliente { get; set; } = "";
        [JsonPropertyName("total_equipos")] public int TotalEquipos { get; set; }

        public string EstadoCss => Estado switch
        {
            "Pendiente" => "pending",
            "Confirmada" => "confirmed",
            "En curso" => "active",
            "Completada" => "complete",
            "Cancelada" => "cancelled",
            _ => "unknown"
        };
    }
    public sealed class CustomerOption
    {
        [JsonPropertyName("usuario_id")] public int UsuarioId { get; set; }
        [JsonPropertyName("nombre_completo")] public string Nombre { get; set; } = "";
        [JsonPropertyName("email")] public string Email { get; set; } = "";
    }

    public sealed class EquipmentOption
    {
        [JsonPropertyName("equipo_id")] public int EquipoId { get; set; }
        [JsonPropertyName("codigo_interno")] public string Codigo { get; set; } = "";
        [JsonPropertyName("descripcion")] public string? Descripcion { get; set; }
        [JsonPropertyName("categoria")] public string Categoria { get; set; } = "";
    }

    public sealed class PaymentMethodOption
    {
        [JsonPropertyName("metodo_pago_id")] public int MetodoPagoId { get; set; }
        [JsonPropertyName("nombre")] public string Nombre { get; set; } = "";
    }
}
