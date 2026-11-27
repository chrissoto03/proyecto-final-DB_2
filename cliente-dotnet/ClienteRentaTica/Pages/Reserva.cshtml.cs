using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ClienteRentaTica.Pages;

public sealed class ReservaModel(IHttpClientFactory factory) : PageModel
{
    public int Id { get; private set; }
    public JsonElement Data { get; private set; }
    public JsonElement Header => Data.GetProperty("reserva");
    public bool Loaded => Data.ValueKind == JsonValueKind.Object;
    public string? Error { get; private set; }
    public string? Notice { get; private set; }
    public List<JsonElement> Methods { get; private set; } = [];
    [BindProperty, ModelBinder(BinderType = typeof(FormMoneyBinder))] public decimal Monto { get; set; }
    [BindProperty] public int Metodo { get; set; }
    public bool Staff => HttpContext.Session.GetString("rentatica-user-role") is "Operador" or "Administrador";
    public bool CanPay => Loaded && Staff && Text(Header, "estado") != "Cancelada" && Money(Header, "saldo") > 0;
    public bool CanReturn(JsonElement item) => Staff && Text(Header, "estado") == "En curso" && Has(item, "fecha_hora_entrega") && !Has(item, "fecha_hora_devolucion");
    public bool AwaitingDelivery => Loaded && Staff && Text(Header, "tipo_reserva") == "Anticipada" && Text(Header, "estado") is "Pendiente" or "Confirmada";
    public string? DeliveryBlock
    {
        get
        {
            if (!AwaitingDelivery) return "La reserva no está pendiente de entrega.";
            if (Text(Header, "estado") != "Confirmada" || Money(Header, "saldo") != 0) return "Completa el pago del alquiler para confirmar la reserva. El depósito de garantía es independiente.";
            if (!Has(Header, "hora_servidor")) return "No se pudo verificar la hora de SQL Server. Actualiza la ficha.";
            var now = Header.GetProperty("hora_servidor").GetDateTime();
            if (now < Header.GetProperty("fecha_inicio").GetDateTime()) return "Aún no llega la hora de inicio. Actualiza la ficha al comenzar el alquiler.";
            if (now >= Header.GetProperty("fecha_fin").GetDateTime()) return "El período de entrega terminó. No se puede entregar esta reserva.";
            if (!Rows("detalles").Any() || Rows("detalles").Any(d => Has(d, "fecha_hora_entrega") || Has(d, "fecha_hora_devolucion") || Text(d, "estado_equipo") is not ("Disponible" or "Reservado"))) return "Revisa los equipos asignados: alguno no está en condiciones de salir o ya fue entregado.";
            return null;
        }
    }
    public async Task<IActionResult> OnPostEntregarAsync(int id)
    {
        Id = id;
        if (!await Load()) return Page();
        if (DeliveryBlock is string reason) { Error = reason; return Page(); }
        if (await Send(HttpMethod.Post, $"api/reservas/{Id}/entrega", new { }) is null)
        { await Load(); return Page(); }
        return RedirectToPage(new { id = Id, resultado = "entrega" });
    }

    public static bool Has(JsonElement item, string key) => item.TryGetProperty(key, out var v) && v.ValueKind != JsonValueKind.Null;
    public static string Text(JsonElement item, string key) => Has(item, key) ? item.GetProperty(key).ToString() : "—";
    public static decimal Money(JsonElement item, string key) => Has(item, key) ? item.GetProperty(key).GetDecimal() : 0;
    // SQL datetime stores the business wall-clock time; do not convert it using the web server timezone.
    public static string Date(JsonElement item, string key) => Has(item, key) ? item.GetProperty(key).GetDateTime().ToString("dd/MM/yyyy HH:mm") : "—";
    public IEnumerable<JsonElement> Rows(string key) => Data.GetProperty(key).EnumerateArray();

    public async Task<IActionResult> OnGetAsync(int id, string? resultado)
    {
        Id = id;
        if (!await Load()) return Page();
        Monto = Money(Header, "saldo");
        Notice = resultado switch { "entrega" => "Equipos entregados. La reserva está en curso.", "pago" => "Pago registrado.", "devolucion" => "Devolución registrada.", _ => null };
        return Page();
    }

    public async Task<IActionResult> OnPostPagarAsync(int id)
    {
        Id = id;
        if (!await Load()) return Page();
        if (!ModelState.IsValid || !CanPay || Monto <= 0 || Monto > Money(Header, "saldo") || decimal.Round(Monto, 2) != Monto || !Methods.Any(m => m.GetProperty("metodo_pago_id").GetInt32() == Metodo))
        { Error = "Revisa el método y el monto: debe ser positivo, tener máximo dos decimales y no superar el saldo actual."; return Page(); }
        if (await Send(HttpMethod.Post, $"api/reservas/{Id}/pagos", new { metodo_pago_id = Metodo, monto = Monto }) is null)
        { await Load(); return Page(); }
        return RedirectToPage(new { id = Id, resultado = "pago" });
    }

    public async Task<IActionResult> OnPostDevolverAsync(int id, int detalleId, string estado, [ModelBinder(BinderType = typeof(FormMoneyBinder))] decimal? devuelto, [ModelBinder(BinderType = typeof(FormMoneyBinder))] decimal? retencion)
    {
        Id = id;
        if (!await Load()) return Page();
        var item = Rows("detalles").FirstOrDefault(d => d.GetProperty("detalle_id").GetInt32() == detalleId);
        if (!ModelState.IsValid || item.ValueKind != JsonValueKind.Object || !CanReturn(item) || estado is not ("Bueno" or "Averiado" or "Perdido"))
        { Error = "El equipo no corresponde a esta reserva o no está pendiente de devolución. Revisa su estado actual."; return Page(); }
        var payload = new Dictionary<string, object> { ["estado_devolucion"] = estado };
        if (devuelto.HasValue) payload["monto_devuelto"] = devuelto.Value;
        if (retencion.HasValue) payload["monto_retencion"] = retencion.Value;
        if (await Send(HttpMethod.Post, $"api/devoluciones/{detalleId}", payload) is null)
        { await Load(); return Page(); }
        return RedirectToPage(new { id = Id, resultado = "devolucion" });
    }

    private async Task<bool> Load()
    {
        if (Id <= 0) { Error = "La reserva indicada no es válida."; return false; }
        var data = await Send(HttpMethod.Get, $"api/reservas/{Id}");
        if (data is null) return false;
        if (!Has(data.Value, "reserva")) { Error = "No se encontró la reserva en este negocio."; return false; }
        Data = data.Value;
        if (CanPay)
        {
            var methods = await Send(HttpMethod.Get, "api/metodos-pago");
            if (methods.HasValue) Methods = methods.Value.GetProperty("datos").EnumerateArray().ToList();
        }
        return true;
    }

    private async Task<JsonElement?> Send(HttpMethod method, string path, object? payload = null)
    {
        var token = HttpContext.Session.GetString("rentatica-api-token");
        if (string.IsNullOrEmpty(token)) { Error = "Inicia sesión para consultar esta reserva."; return null; }
        try
        {
            using var request = new HttpRequestMessage(method, path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            if (payload is not null) request.Content = JsonContent.Create(payload);
            using var response = await factory.CreateClient("RentaTicaApi").SendAsync(request);
            using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            if (!response.IsSuccessStatusCode)
            { Error = document.RootElement.TryGetProperty("error", out var error) ? error.GetString() : "No se pudo completar la operación."; return null; }
            return document.RootElement.Clone();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            Error = method == HttpMethod.Post
                ? "No se pudo confirmar el resultado. Actualiza esta ficha y revisa los pagos y equipos antes de repetir la operación."
                : "No se pudo consultar el API. Comprueba la conexión y vuelve a abrir esta ficha.";
            return null;
        }
    }
}

// HTML number inputs submit a dot decimal separator regardless of Windows culture.
public sealed class FormMoneyBinder : Microsoft.AspNetCore.Mvc.ModelBinding.IModelBinder
{
    public Task BindModelAsync(Microsoft.AspNetCore.Mvc.ModelBinding.ModelBindingContext context)
    {
        var value = context.ValueProvider.GetValue(context.ModelName);
        if (value == Microsoft.AspNetCore.Mvc.ModelBinding.ValueProviderResult.None) return Task.CompletedTask;
        context.ModelState.SetModelValue(context.ModelName, value);
        if (decimal.TryParse(value.FirstValue, System.Globalization.NumberStyles.AllowDecimalPoint | System.Globalization.NumberStyles.AllowLeadingSign,
            System.Globalization.CultureInfo.InvariantCulture, out var amount))
            context.Result = Microsoft.AspNetCore.Mvc.ModelBinding.ModelBindingResult.Success(amount);
        else context.ModelState.TryAddModelError(context.ModelName, "Indica un monto válido.");
        return Task.CompletedTask;
    }
}
