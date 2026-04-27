# 🌿 Bazar de la Magnolia — Huerto Creativo

Aplicación web full-stack inspirada en tiendas reales tipo vivero boutique (como Pistils Nursery), enfocada en la venta de productos naturales, arte y conservas.

El sistema permite gestionar productos, visualizar catálogos, manejar stock y realizar compras, todo con una arquitectura escalable y moderna.

---

## ✨ Características principales

- 🪴 Catálogo de productos dinámico (plantas, arte, conservas)
- 🔍 Filtro por categorías y tipos de productos
- 🧾 Página individual por producto
- 🛒 Sistema de carrito de compras
- 📦 Gestión automática de stock
- 🧑‍💻 Panel administrativo básico
- 🗃️ Base de datos relacional optimizada (modelo padre/hijo)
- 🎨 Diseño moderno tipo tienda real (UX/UI cuidado)

---

## 🧠 Arquitectura del sistema

El proyecto está dividido en dos grandes capas:

### 🔹 Frontend (Cliente)
- React
- React Router
- CSS puro (custom design system)
- Manejo de estado con hooks
- Consumo de API REST

### 🔹 Backend (Servidor)
- Node.js + Express
- MySQL (con mysql2/promise)
- API REST
- Manejo de transacciones (órdenes + stock)
- Generación de UUID para productos

---

## 📂 Estructura del proyecto
bazar-magnolia/
│
├── backend/
│ ├── server.js
│ ├── .env
│ ├── init.sql
│ └── img/ # imágenes estáticas
│
├── frontend/
│ ├── src/
│ │ ├── components/
│ │ ├── pages/
│ │ ├── styles/
│ │ ├── App.jsx
│ │ └── main.jsx
│ │
│ └── package.json
│
└── README.md

---

## 🗄️ Modelo de base de datos

Se utiliza una arquitectura **padre/hijo**, que permite escalabilidad real:

### 🔹 Tabla principal
```sql
products
Contiene:

nombre
precio
stock
imagen
categoría
tipo (plant / conserva / arte)

🔹 Tablas especializadas
plants
conservas
arte

Ventaja

Este modelo evita:

columnas innecesarias
datos nulos
mala escalabilidad
