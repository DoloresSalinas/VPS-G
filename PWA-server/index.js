const express = require("express");
const cors = require("cors");
const pool = require("./db");
const authRoutes = require("./routes/auth");
const { verifyToken } = require("./middleware/auth");

const app = express();
app.use(cors());
app.use(express.json());

// Rutas de autenticación
app.use("/api", authRoutes);

// Ruta protegida de prueba
app.get("/api/protected", verifyToken, (req, res) => {
  res.json({ message: "Ruta protegida", user: req.user });
});

// Obtener todos los usuarios (incluye admin)
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM usuarios');
    
    console.log(res.json(result.rows));
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
const PORT = 3001;
app.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
});
