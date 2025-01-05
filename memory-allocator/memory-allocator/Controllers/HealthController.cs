using System.Net;
using Microsoft.AspNetCore.Mvc;

namespace memory_allocator.Controllers;

[ApiController]
[Route("/health")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public ActionResult Health()
    {
        return new StatusCodeResult((int)HttpStatusCode.OK);
    }
}