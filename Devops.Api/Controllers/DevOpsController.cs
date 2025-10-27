using Devops.Api.Models;
using Devops.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Devops.Api.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class DevOpsController : ControllerBase
    {
        private const string ApiKey = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c";
        private readonly JwtService _jwtService;

        public DevOpsController(JwtService jwtService)
        {
            _jwtService = jwtService;
        }

        [HttpPost]
        public IActionResult Post([FromBody] DevOpsRequest request)
        {
            // Validar request null
            if (request == null)
                return BadRequest("Invalid request");

            // Validar API Key
            var headerKey = Request.Headers["X-Parse-REST-API-Key"].FirstOrDefault();
            if (headerKey != ApiKey)
                return Unauthorized("ERROR");

            // Generar JWT único por transacción
            var jwt = _jwtService.GenerateToken();
            Response.Headers.Add("X-JWT-KWY", jwt);

            var response = new DevOpsResponse
            {
                Message = $"Hello {request.To} your message will be sent"
            };

            return Ok(response);
        }

        [HttpGet, HttpPut, HttpDelete, HttpPatch]
        public IActionResult InvalidMethods()
        {
            return BadRequest("ERROR");
        }
    }
}
