using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
namespace ClienteRentaTica.Pages;

public sealed class ModificarReservaModel(IHttpClientFactory factory) : PageModel
{
    public int Id { get; private set; }
    [BindProperty] public DateTime Inicio { get; set; }
    [BindProperty] public DateTime Fin { get; set; }
    [BindProperty] public int[] Equipos { get; set; } = [];
    [BindProperty] public string? Confirmacion { get; set; }
    public JsonElement? Revision { get; private set; }
    public List<JsonElement> Catalogo { get; private set; } = [];
    public string? Error { get; private set; }
    public bool Editable { get; private set; }
    private bool ApiOk;

    public async Task OnGetAsync(int id)
    {
        Id = id;
        await Load(true);
    }
    public async Task<IActionResult> OnPostRevisarAsync(int id)
    {
        Id = id;
        if (!await Load(false)) return Page();
        if (!ModelState.IsValid || Inicio == default || Fin <= Inicio || Equipos.Length == 0)
        { Error = "Indica un rango válido y selecciona al menos un equipo."; return Page(); }
        var result = await Send(HttpMethod.Post, $"api/reservas/{Id}/modificacion/revisar", new
        {
            fecha_inicio = Inicio.ToString("yyyy-MM-ddTHH:mm:ss.fff", System.Globalization.CultureInfo.InvariantCulture),
            fecha_fin = Fin.ToString("yyyy-MM-ddTHH:mm:ss.fff", System.Globalization.CultureInfo.InvariantCulture),
            equipo_ids = Equipos
        });
        SetReview(result);
        return Page();
    }
    public async Task<IActionResult> OnPostConfirmarAsync(int id)
    {
        Id = id;
        if (!await Load(false)) return Page();
        var result = await Send(HttpMethod.Post, $"api/reservas/{Id}/modificacion/confirmar", new { confirmacion = Confirmacion });
        if (ApiOk) return RedirectToPage("/Reserva", new { id = Id, resultado = "modificacion" });
        SetReview(result);
        return Page();
    }
    private void SetReview(JsonElement? result)
    {
        if (result is JsonElement r && r.TryGetProperty("resumen", out _))
        {
            Revision = r;
            Confirmacion = r.GetProperty("confirmacion").GetString();
            // A renewed quote must replace the submitted hidden token.
            ModelState.Remove(nameof(Confirmacion));
        }
    }
    private async Task<bool> Load(bool defaults)
    {
        if (Id <= 0) { Error = "Reserva inválida."; return false; }
        var result = await Send(HttpMethod.Get, $"api/reservas/{Id}");
        if (!ApiOk || result is null) return false;
        var r = result.Value.GetProperty("reserva");
        var details = result.Value.GetProperty("detalles").EnumerateArray().ToArray();
        Editable = r.GetProperty("tipo_reserva").GetString() == "Anticipada"
            && r.GetProperty("estado").GetString() is "Pendiente" or "Confirmada"
            && r.GetProperty("hora_servidor").GetDateTime() < r.GetProperty("fecha_inicio").GetDateTime()
            && details.All(d => !ReservaModel.Has(d, "fecha_hora_entrega") && !ReservaModel.Has(d, "fecha_hora_devolucion"));
        if (!Editable) { Error = "Esta reserva ya no admite modificaciones: debe ser anticipada, no haber iniciado y no tener equipos entregados."; return false; }
        if (defaults)
        {
            Inicio = r.GetProperty("fecha_inicio").GetDateTime();
            Fin = r.GetProperty("fecha_fin").GetDateTime();
            Equipos = details.Select(d => d.GetProperty("equipo_id").GetInt32()).ToArray();
        }
        var catalog = await Send(HttpMethod.Get, $"api/reservas/{Id}/modificacion/equipos");
        if (ApiOk && catalog.HasValue) Catalogo = catalog.Value.GetProperty("datos").EnumerateArray().ToList();
        return ApiOk;
    }
    private async Task<JsonElement?> Send(HttpMethod method, string path, object? payload = null)
    {
        ApiOk = false;
        var token = HttpContext.Session.GetString("rentatica-api-token");
        if (string.IsNullOrWhiteSpace(token)) { Error = "Inicia sesión para modificar esta reserva."; return null; }
        try
        {
            using var request = new HttpRequestMessage(method, path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            if (payload is not null) request.Content = JsonContent.Create(payload);
            using var response = await factory.CreateClient("RentaTicaApi").SendAsync(request);
            using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            ApiOk = response.IsSuccessStatusCode;
            if (!ApiOk) Error = document.RootElement.TryGetProperty("error", out var e) ? e.GetString() : "No se pudo completar la modificación.";
            return document.RootElement.Clone();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            Error = "No se pudo confirmar el resultado. Vuelve a la ficha y comprueba sus datos antes de repetir la operación.";
            return null;
        }
    }
}
