import http from "k6/http";
import { check, sleep } from "k6";

const TOKEN = __ENV.GRAFANA_API_TOKEN;
 
export const options = {
  stages: [
    { duration: "10s", target: 5 },  // 5 usuarios concurrentes
    { duration: "20s", target: 10 }, // sube a 10 usuarios
    { duration: "10s", target: 0 },  // baja gradualmente
  ],
};

// URL base de backend
const BASE_URL = "http://localhost:3001/api";  
const ALOJA_URL = "http://localhost:3001/al"; 

export default function () { 
  const loginPayload = JSON.stringify({
    email: "emma2@gmail.com",   
    password: "Emma&illenco2",   
  });

  const loginHeaders = { "Content-Type": "application/json" };
  const loginRes = http.post(`${BASE_URL}/login`, loginPayload, {
    headers: loginHeaders,
  });

  check(loginRes, {
    "login exitoso": (r) => r.status === 200 && r.json("token") !== "",
  });

  const token = loginRes.json("token");
 
  if (token) {
    const protectedRes = http.get(`${BASE_URL}/protected`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    check(protectedRes, {
      "acceso autorizado": (r) => r.status === 200,
    });
  } 

  const alRes = http.get(`${ALOJA_URL}`);
  check(alRes, {
    "lista de alojamientos obtenida": (r) => r.status === 200,
  });

  const lista = alRes.json();
  if (lista && lista.length > 0) {
    const idAlojamiento = lista[0].id_alojamiento;
    const detalleRes = http.get(`${ALOJA_URL}/${idAlojamiento}`);
    check(detalleRes, {
      "detalle de alojamiento obtenido": (r) => r.status === 200,
    });
  }

  sleep(1);
}
