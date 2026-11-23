using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ClienteRentaTica.Pages;

public sealed class IndexModel(IHttpClientFactory httpClientFactory) : PageModel
{
    private const string TokenKey = "rentatica-api-token";
    private const string EmailKey = "rentatica-user-email";
    private const string NameKey = "rentatica-user-name";
    private const string RoleKey = "rentatica-user-role";

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    [BindProperty]
    public LoginInput Input { get; set; } = new();

    [BindProperty]
    public string? Estado { get; set; } = "Disponible";

    public bool IsAuthenticated => !string.IsNullOrWhiteSpace(HttpContext.Session.GetString(TokenKey));
    public string DisplayEmail => HttpContext.Session.GetString(EmailKey) ?? "";
    public string DisplayName => HttpContext.Session.GetString(NameKey) ?? DisplayEmail;
    public string DisplayRole => HttpContext.Session.GetString(RoleKey) ?? "";
    public string? StatusMessage { get; private set; }
    public string? ErrorMessage { get; private set; }
    public string? ResponseJson { get; private set; }

    public async Task<IActionResult> OnPostLoginAsync()
    {
        if (!ModelState.IsValid)
        {
            var validationErrors = ModelState
                .Where(entry => entry.Value is not null && entry.Value.Errors.Count > 0)
                .SelectMany(entry => entry.Value!.Errors.Select(error =>
                    string.IsNullOrWhiteSpace(error.ErrorMessage)
                        ? $"{entry.Key}: valor inválido."
                        : $"{entry.Key}: {error.ErrorMessage}"))
                .ToArray();

            ErrorMessage = validationErrors.Length == 0
                ? "El formulario no pasó la validación. Revisa los campos e intenta otra vez."
                : string.Join(" ", validationErrors);
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
            StatusMessage = "Inicio de sesión correcto. El token se guarda en la sesión del cliente.";
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

    public Task<IActionResult> OnPostEquiposAsync()
    {
        var estado = Uri.EscapeDataString(Estado ?? "Disponible");
        return GetProtectedAsync("api/equipos?estado=" + estado, "Consulta de equipos completada.");
    }

    public Task<IActionResult> OnPostReporteInventarioAsync()
    {
        return GetProtectedAsync("api/reportes/inventario", "Reporte de inventario completado.");
    }

    public IActionResult OnPostLogout()
    {
        HttpContext.Session.Clear();
        StatusMessage = "La sesión se cerró.";
        return Page();
    }

    private async Task<IActionResult> GetProtectedAsync(string relativePath, string successMessage)
    {
        var token = HttpContext.Session.GetString(TokenKey);
        if (string.IsNullOrWhiteSpace(token))
        {
            ErrorMessage = "Inicia sesión antes de consultar el API.";
            return Page();
        }

        try
        {
            var client = httpClientFactory.CreateClient("RentaTicaApi");
            using var request = new HttpRequestMessage(HttpMethod.Get, relativePath);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var response = await client.SendAsync(request);
            var body = await response.Content.ReadAsStringAsync();

            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                HttpContext.Session.Clear();
                ErrorMessage = "La sesión venció o el token ya no es válido. Inicia sesión otra vez.";
                return Page();
            }

            if (!response.IsSuccessStatusCode)
            {
                ErrorMessage = ReadApiError(body) ?? "El API respondió con HTTP " + (int)response.StatusCode + ".";
                return Page();
            }

            ResponseJson = FormatJson(body);
            StatusMessage = successMessage;
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
}



