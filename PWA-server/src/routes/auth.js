const express = require("express");
const pool = require("../db");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
require('dotenv').config();

const router = express.Router();

// Registro
router.post("/register", async (req, res) => {
  try {
    const { nombre, apellido, email, telefono, password } = req.body;
    if (!nombre || !apellido || !email || !telefono || !password)
      return res.status(400).json({ error: "Todos los campos son obligatorios" });

    const existingUser = await pool.query(
      "SELECT * FROM usuarios WHERE email = $1",
      [email]
    );
    if (existingUser.rows.length > 0)
      return res.status(400).json({ error: "El correo ya está registrado" });

    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO usuarios (nombre, apellido, email, telefono, contrasena) 
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [nombre, apellido, email, telefono, hashedPassword]
    );

    res.status(201).json({ message: "Usuario registrado exitosamente", usuario: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error al registrar usuario" });
  }
});

// Login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ error: "Todos los campos son obligatorios" });

    const userResult = await pool.query("SELECT * FROM usuarios WHERE email = $1", [email]);
    if (userResult.rows.length === 0)
      return res.status(400).json({ error: "Usuario o contraseña incorrectos" });

    const user = userResult.rows[0];
    const isMatch = await bcrypt.compare(password, user.contrasena);
    if (!isMatch)
      return res.status(400).json({ error: "Usuario o contraseña incorrectos" });

    const token = jwt.sign(
      { id: user.id_us, nombre: user.nombre, rol: user.rol },
      process.env.JWT_SECRET,
      { expiresIn: "1d" }
    );

    res.json({
      message: "Login exitoso",
      token,
      usuario: {
        id: user.id_us,
        nombre: user.nombre,
        apellido: user.apellido,
        email: user.email,
        rol: user.rol
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error al iniciar sesión" });
  }
});

module.exports = router;
