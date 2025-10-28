using Xunit;
using Devops.Api.Controllers;
using Devops.Api.Models;
using Devops.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;
using Microsoft.AspNetCore.Http;

namespace Devops.Api.Tests
{
    public class DevOpsControllerTests
    {
        private readonly JwtService _jwtService;
        private readonly DevOpsController _controller;

        public DevOpsControllerTests()
        {
            // Configuración en memoria
            var inMemorySettings = new Dictionary<string, string>
            {
                {"Jwt:Key", "mysupersecretkeythatshouldbeatleast32byteslong"},
                {"Jwt:Issuer", "test-issuer"},
                {"Jwt:Audience", "test-audience"}
            };

            IConfiguration configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings)
                .Build();

            _jwtService = new JwtService(configuration);
            _controller = new DevOpsController(_jwtService);

            // Simulación de HttpContext para headers
            _controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            };
        }

        [Fact]
        public void Post_NullRequest_ReturnsBadRequest()
        {
            var result = _controller.Post(null);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("Invalid request", badRequest.Value);
        }

        [Fact]
        public void Post_InvalidApiKey_ReturnsUnauthorized()
        {
            _controller.Request.Headers["X-Parse-REST-API-Key"] = "wrong-key";

            var request = new DevOpsRequest
            {
                Message = "Hello",
                To = "Juan",
                From = "Rita",
                TimeToLifeSec = 45
            };

            var result = _controller.Post(request);
            var unauthorized = Assert.IsType<UnauthorizedObjectResult>(result);
            Assert.Equal("ERROR", unauthorized.Value);
        }

        [Fact]
        public void Post_ValidRequest_ReturnsOkWithJwt()
        {
            _controller.Request.Headers["X-Parse-REST-API-Key"] = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c";

            var request = new DevOpsRequest
            {
                Message = "This is a test",
                To = "Juan Perez",
                From = "Rita Asturia",
                TimeToLifeSec = 45
            };

            var result = _controller.Post(request);
            var okResult = Assert.IsType<OkObjectResult>(result);
            var response = Assert.IsType<DevOpsResponse>(okResult.Value);

            Assert.Equal("Hello Juan Perez your message will be sent", response.Message);
            Assert.True(_controller.Response.Headers.ContainsKey("X-JWT-KWY"));
        }

        [Theory]
        [InlineData("GET")]
        [InlineData("PUT")]
        [InlineData("DELETE")]
        [InlineData("PATCH")]
        public void InvalidMethods_ReturnsBadRequest(string httpMethod)
        {
            // Simular el método HTTP
            _controller.ControllerContext.HttpContext.Request.Method = httpMethod;

            var result = _controller.InvalidMethods();
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("ERROR", badRequest.Value);
        }
    }
}
