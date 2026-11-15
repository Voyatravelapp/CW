// Servidor estático mínimo para desarrollo local (sin dependencias).
// Uso: npm run dev
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";

const root = resolve(process.cwd());
const port = Number(process.env.PORT || 5173);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2"
};

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://localhost:${port}`);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname === "/") pathname = "/index.html";

    let filePath = resolve(join(root, normalize(pathname)));
    if (filePath !== root && !filePath.startsWith(root + "/")) {
      res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Acceso denegado");
      return;
    }

    const info = await stat(filePath);
    if (info.isDirectory()) filePath = join(filePath, "index.html");

    const data = await readFile(filePath);
    res.writeHead(200, {
      "Content-Type": types[extname(filePath).toLowerCase()] || "application/octet-stream",
      "Cache-Control": "no-store"
    });
    res.end(data);
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("No encontrado");
  }
});

server.listen(port, () => {
  console.log("");
  console.log("  CW Inmobiliaria · servidor local");
  console.log("  Web:          http://localhost:" + port + "/");
  console.log("  Portal:       http://localhost:" + port + "/portal.html");
  console.log("  Portal demo:  http://localhost:" + port + "/portal.html?demo=1");
  console.log("");
});
