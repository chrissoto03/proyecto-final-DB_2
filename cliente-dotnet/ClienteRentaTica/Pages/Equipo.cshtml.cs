using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
namespace ClienteRentaTica.Pages;
public sealed class EquipoModel(IHttpClientFactory factory) : PageModel
{
 public int Id { get; private set; }
 public JsonElement? Data { get; private set; }
 public JsonElement Equipo => Data!.Value.GetProperty("equipo");
 public IEnumerable<JsonElement> History => Data!.Value.GetProperty("mantenimientos").EnumerateArray();
 public IEnumerable<JsonElement> Reservas => Data!.Value.GetProperty("reservas").EnumerateArray();
 public string? Error { get; private set; }
 public string? Notice { get; private set; }
 [BindProperty] public string? Descripcion { get; set; }
 [BindProperty] public string Tipo { get; set; } = "Correctivo";
 [BindProperty, ModelBinder(BinderType=typeof(FormMoneyBinder))] public decimal Costo { get; set; }
 public bool CanStart => Data.HasValue && ReservaModel.Text(Equipo,"estado") is "Averiado" or "Disponible" && !History.Any(m=>!ReservaModel.Has(m,"fecha_fin"));
 public async Task OnGetAsync(int id,string? resultado) { Id=id;await Load();Notice=resultado switch {"inicio"=>"Mantenimiento registrado. El equipo queda fuera de disponibilidad.","fin"=>"Mantenimiento finalizado. Revisa el estado actualizado del equipo.",_=>null}; }
 public async Task<IActionResult> OnPostIniciarAsync(int id)
 {
  Id=id;if(!await Load())return Page();
  if(!CanStart||!ModelState.IsValid||string.IsNullOrWhiteSpace(Descripcion)||Descripcion.Trim().Length>300||Tipo is not ("Correctivo" or "Preventivo")||Costo<0||Costo>99999999.99m||decimal.Round(Costo,2)!=Costo)
  {Error="Revisa el estado del equipo, la descripción (hasta 300 caracteres) y el costo (no negativo, máximo dos decimales).";return Page();}
  if(await Send(HttpMethod.Post,$"api/equipos/{Id}/mantenimientos",new {descripcion=Descripcion.Trim(),tipo=Tipo,costo=Costo}) is null)return Page();
  return RedirectToPage(new {id=Id,resultado="inicio"});
 }
 public async Task<IActionResult> OnPostFinalizarAsync(int id,int mantenimientoId,string estadoEquipo)
 {
  Id=id;if(!await Load())return Page();
  ModelState.Remove(nameof(Tipo));
  ModelState.Remove(nameof(Descripcion));
  if(!ModelState.IsValid||Costo<0||Costo>99999999.99m||decimal.Round(Costo,2)!=Costo||estadoEquipo is not ("Disponible" or "Averiado" or "Fuera de servicio")||!History.Any(m=>m.GetProperty("mantenimiento_id").GetInt32()==mantenimientoId&&!ReservaModel.Has(m,"fecha_fin")))
  {Error="El mantenimiento no está abierto en este equipo o el costo/resultado no es válido.";return Page();}
  if(await Send(HttpMethod.Post,$"api/mantenimientos/{mantenimientoId}/finalizar",new {costo=Costo,estado_equipo=estadoEquipo}) is null)return Page();
  return RedirectToPage(new {id=Id,resultado="fin"});
 }
 private async Task<bool> Load(){Data=await Send(HttpMethod.Get,$"api/equipos/{Id}/ficha");return Data.HasValue;}
 private async Task<JsonElement?> Send(HttpMethod method,string path,object? payload=null)
 {
  var token=HttpContext.Session.GetString("rentatica-api-token");if(string.IsNullOrEmpty(token)){Error="Inicia sesión para gestionar el equipo.";return null;}
  try{using var request=new HttpRequestMessage(method,path);request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",token);if(payload is not null)request.Content=JsonContent.Create(payload);
   using var response=await factory.CreateClient("RentaTicaApi").SendAsync(request);using var json=JsonDocument.Parse(await response.Content.ReadAsStringAsync());
   if(!response.IsSuccessStatusCode){Error=json.RootElement.TryGetProperty("error",out var error)?error.GetString():"No se pudo completar la operación.";return null;}return json.RootElement.Clone();
  }catch(Exception ex)when(ex is HttpRequestException or TaskCanceledException or JsonException){Error="No se pudo confirmar el resultado. Actualiza la ficha antes de repetir la operación.";return null;}
 }
}
