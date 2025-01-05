using System.Net;
using System.Runtime.InteropServices;
using Microsoft.AspNetCore.Mvc;

namespace memory_allocator.Controllers;

[ApiController]
[Route("/")]
public class MemoryAllocatorController : ControllerBase
{
    [HttpPost]
    public unsafe ActionResult Create(int memory)
    {
        var size = (int)(memory * Math.Pow(1024, 2));
        var pointer = Marshal.AllocCoTaskMem(size);
        
        var dst = (byte *)pointer.ToPointer();
        for (var i = 0; i < size; i++)
        {
            dst[i] = 0;
        }
        
        return new StatusCodeResult((int)HttpStatusCode.OK);
    }
}
