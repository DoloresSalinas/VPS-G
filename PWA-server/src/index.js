const express = require("express");
const cors = require("cors");
const pool = require("./db");
const authRoutes = require("./routes/auth");
const { verifyToken } = require("./middleware/auth");

const APP_COLOR = process.env.APP_COLOR || 'default';
const PORT = process.env.PORT || 3001;

const app = express();
app.use(cors());
app.use(express.json());

// Rutas de autenticación
app.use("/api", authRoutes);

app.get('/', async (req, res) => {
    try {
        // Obtener usuarios de la BD
        const result = await pool.query('SELECT * FROM usuarios');
        const usuarios = result.rows;

        // Crear filas HTML
        const htmlUsuarios = usuarios.map(u => `
            <tr>
                <td>${u.id_us}</td>
                <td>${u.nombre}</td>
                <td>${u.email}</td>
            </tr>
        `).join("");

        res.send(`
            <!DOCTYPE html>
            <html lang="es">
            <head>
                <title>PWAaa Server Status</title>
                <style>
                    body { font-family: sans-serif; margin: 40px; }
                    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
                    th { background: #eee; }
                    .color-indicator { 
                        font-size: 1.2em; 
                        padding: 6px 12px; 
                        border-radius: 5px; 
                        background-color: ${APP_COLOR === 'blue' ? '#3b82f6' :
                            APP_COLOR === 'green' ? '#10b981' : '#f59e0b'};
                        color: white;
                        display: inline-block;
                        margin-bottom: 20px;
                    }
                </style>
            </head>
            <body>

                <h1>Mi Aplicación PWA</h1>
                <p>Esta es la versión desplegada y funcionando.</p>

                <div class="color-indicator">Ambiente: ${APP_COLOR.toUpperCase()}</div>

                <h2>Usuarios Registrados</h2>

                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Nombre</th>
                            <th>Email</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${htmlUsuarios}
                    </tbody>
                </table>

            </body>
            </html>
        `);

    } catch (error) {
        console.error(error);
        res.status(500).send("Error al obtener usuarios");
    }
});


app.get("/ping/example", (req, res) => {
    res.json({ message: "Despliegue automático OK para realizar pruebas", environment: APP_COLOR });
});

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', color: APP_COLOR });
});

app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'ok', color: APP_COLOR });
});

// Ruta protegida de prueba
app.get("/api/protected", verifyToken, (req, res) => {
    res.json({ message: "Ruta protegida", user: req.user });
});

app.get('/users', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM usuarios');
        
        console.log(result.rows);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar usuarios' });
    }
});

app.get('/al', async (req, res) => {
    try {
        console.log("alojamientos con imágenes agrupadas");

        const result = await pool.query(`
             SELECT 
                 a.id_alojamiento,
                 a.anfitrion_id,
                 a.titulo,
                 a.descripcion,
                 a.tipo,
                 a.direccion,
                 a.ciudad,
                 a.pais,
                 a.precio_base, 
                 a.disponible,
                 ARRAY_AGG(i.url_imagen) FILTER (WHERE i.url_imagen IS NOT NULL) AS imagenes
             FROM alojamientos a
             LEFT JOIN imagenes i ON a.id_alojamiento = i.alojamiento_id
             GROUP BY 
                 a.id_alojamiento,
                 a.anfitrion_id,
                 a.titulo,
                 a.descripcion,
                 a.tipo,
                 a.direccion,
                 a.ciudad,
                 a.pais,
                 a.precio_base, 
                 a.disponible
             ORDER BY a.id_alojamiento;
        `);

        console.log("Registros obtenidos:", result.rows.length);
        res.json(result.rows);

    } catch (err) {
        console.error("Error:", err);
        res.status(500).json({ error: 'Error al consultar alojamientos' });
    }
});

app.get('/al/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(`
            SELECT 
              a.id_alojamiento,
              a.anfitrion_id,
              a.titulo,
              a.descripcion,
              a.tipo,
              a.direccion,
              a.ciudad,
              a.pais,
              a.precio_base, 
              a.disponible,
              COALESCE(
                  JSON_AGG(
                      JSON_BUILD_OBJECT(
                          'url', i.url_imagen,
                          'descripcion', i.descripcion
                      )
                  ) FILTER (WHERE i.url_imagen IS NOT NULL), '[]'
              ) AS imagenes
            FROM alojamientos a
            LEFT JOIN imagenes i ON a.id_alojamiento = i.alojamiento_id
            WHERE a.id_alojamiento = $1
            GROUP BY a.id_alojamiento
        `, [id]);

        res.json(result.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar alojamiento' });
    }
});



app.get('/aloja', async (req, res) => {
    try {
        console.log("Alojamiento sin imagen");
        const result = await pool.query('SELECT * FROM alojamientos LIMIT 1;');
        console.log("Registros obtenidos:", result);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar usuarios' });
    }
});

app.get('/cu', async (req, res) => {
    try {
        console.log("Alojamiento sin imagen");
        const result = await pool.query('SELECT * FROM cuartos LIMIT 1;');
        console.log("Registros obtenidos:", result);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar usuarios' });
    }
});

app.get('/imag', async (req, res) => {
    try {
        console.log("Imagenes");
        const result = await pool.query('select * from imagenes;');
        console.log("Registros obtenidos:", result);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar usuarios' });
    }
});

app.get('/reservations', async (req, res) => {
    try {
        console.log("Reservas");
        const result = await pool.query('SELECT * FROM reservas');
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Error al consultar usuarios' });
    }
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`Servidor corriendo en http://127.0.0.1:${PORT} (Color: ${APP_COLOR.toUpperCase()})`);
});

