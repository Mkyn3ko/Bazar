const express = require("express");
const cors = require("cors");
const mysql = require("mysql2/promise");
const dotenv = require("dotenv");
const crypto = require("crypto");
const path = require("path");

dotenv.config();

const app = express();

app.use(
  cors({
    origin: "http://localhost:3000"
  })
);

app.use(express.json());
app.use("/img", express.static(path.join(__dirname, "img")));

const PORT = process.env.PORT || 4000;

let db;

function generateUuid() {
  return crypto.randomUUID();
}

async function connectDB() {
  try {
    db = await mysql.createPool({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });

    console.log("Conectado a MySQL");
  } catch (error) {
    console.error("Error conectando a MySQL:", error.message);
  }
}

function parseMaybeJson(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;

  try {
    return JSON.parse(value);
  } catch {
    return [];
  }
}

app.get("/", (req, res) => {
  res.json({ message: "Backend funcionando" });
});

app.get("/health", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT 1 AS ok");
    res.json({ status: "ok", db: rows[0].ok === 1 ? "up" : "down" });
  } catch (error) {
    res.status(500).json({
      status: "error",
      db: "down",
      error: error.message
    });
  }
});

/* =========================================
   AUTH
========================================= */
app.post("/login", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: "Faltan email o password" });
  }

  try {
    const [rows] = await db.query(
      "SELECT id, name, email, role FROM users WHERE email = ? AND password = ?",
      [email, password]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: "Credenciales incorrectas" });
    }

    res.json({
      message: "Login correcto",
      user: rows[0]
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* =========================================
   CATEGORIES
========================================= */
app.get("/categories", async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, name, description, created_at
       FROM categories
       ORDER BY name ASC`
    );

    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* =========================================
   PRODUCTS
========================================= */
app.get("/products", async (req, res) => {
  const { module, category_id, active } = req.query;

  const conditions = [];
  const params = [];

  if (module) {
    conditions.push("p.module_type = ?");
    params.push(module);
  }

  if (category_id) {
    conditions.push("p.category_id = ?");
    params.push(Number(category_id));
  }

  if (active !== undefined) {
    conditions.push("p.active = ?");
    params.push(active === "true" ? 1 : 0);
  }

  const whereClause =
    conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

  try {
    const [rows] = await db.query(
      `
      SELECT
        p.id,
        p.module_type,
        p.category_id,
        c.name AS category_name,

        p.name,
        p.subtitle,
        p.description,
        p.tags,
        p.unit,
        p.price,
        p.stock,
        p.available,
        p.active,
        p.image_url,
        p.image_alt,
        p.created_at,
        p.updated_at,

        pl.scientific_name,
        COALESCE(pl.variety, co.variety) AS variety,
        pl.care,

        co.ingredients,
        co.weight_ml,
        co.expiry_date,

        ar.artist,
        ar.technique,
        ar.dimensions

      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN plants pl ON pl.product_id = p.id
      LEFT JOIN conservas co ON co.product_id = p.id
      LEFT JOIN arte ar ON ar.product_id = p.id
      ${whereClause}
      ORDER BY p.created_at DESC, p.name ASC
      `,
      params
    );

    const normalizedRows = rows.map((row) => ({
      ...row,
      tags: parseMaybeJson(row.tags)
    }));

    res.json(normalizedRows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/products/:id", async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT
        p.id,
        p.module_type,
        p.category_id,
        c.name AS category_name,

        p.name,
        p.subtitle,
        p.description,
        p.tags,
        p.unit,
        p.price,
        p.stock,
        p.available,
        p.active,
        p.image_url,
        p.image_alt,
        p.created_at,
        p.updated_at,

        pl.scientific_name,
        COALESCE(pl.variety, co.variety) AS variety,
        pl.care,

        co.ingredients,
        co.weight_ml,
        co.expiry_date,

        ar.artist,
        ar.technique,
        ar.dimensions

      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN plants pl ON pl.product_id = p.id
      LEFT JOIN conservas co ON co.product_id = p.id
      LEFT JOIN arte ar ON ar.product_id = p.id
      WHERE p.id = ?
      `,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Producto no encontrado" });
    }

    const [images] = await db.query(
      `
      SELECT id, url, alt, display_order, created_at
      FROM product_images
      WHERE product_id = ?
      ORDER BY display_order ASC, id ASC
      `,
      [req.params.id]
    );

    res.json({
      ...rows[0],
      tags: parseMaybeJson(rows[0].tags),
      images
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/products", async (req, res) => {
  const {
    module_type,
    category_id,
    name,
    subtitle,
    description,
    tags,
    unit,
    price,
    stock,
    available,
    active,
    image_url,
    image_alt,

    scientific_name,
    variety,
    care,

    ingredients,
    weight_ml,
    expiry_date,

    artist,
    technique,
    dimensions
  } = req.body;

  if (!module_type || !["plant", "conserva", "arte"].includes(module_type)) {
    return res.status(400).json({ error: "module_type inválido" });
  }

  if (!name || price === undefined || price === null) {
    return res.status(400).json({ error: "Nombre y precio son obligatorios" });
  }

  const numericStock = Number(stock ?? 0);
  const numericPrice = Number(price);

  if (!Number.isFinite(numericStock) || numericStock < 0) {
    return res.status(400).json({ error: "El stock debe ser 0 o mayor" });
  }

  if (!Number.isFinite(numericPrice) || numericPrice < 0) {
    return res.status(400).json({ error: "El precio debe ser 0 o mayor" });
  }

  const newId = generateUuid();
  const tagsJson = Array.isArray(tags) ? JSON.stringify(tags) : JSON.stringify([]);

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    await connection.query(
      `
      INSERT INTO products (
        id,
        module_type,
        category_id,
        name,
        subtitle,
        description,
        tags,
        unit,
        price,
        stock,
        available,
        active,
        image_url,
        image_alt
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        newId,
        module_type,
        category_id || null,
        name,
        subtitle || null,
        description || null,
        tagsJson,
        unit || "unidad",
        numericPrice,
        numericStock,
        available === undefined ? 1 : available ? 1 : 0,
        active === undefined ? 1 : active ? 1 : 0,
        image_url || null,
        image_alt || null
      ]
    );

    if (module_type === "plant") {
      await connection.query(
        `
        INSERT INTO plants (
          product_id,
          scientific_name,
          variety,
          care
        )
        VALUES (?, ?, ?, ?)
        `,
        [
          newId,
          scientific_name || null,
          variety || null,
          care || null
        ]
      );
    }

    if (module_type === "conserva") {
      await connection.query(
        `
        INSERT INTO conservas (
          product_id,
          variety,
          ingredients,
          weight_ml,
          expiry_date
        )
        VALUES (?, ?, ?, ?, ?)
        `,
        [
          newId,
          variety || null,
          ingredients || null,
          weight_ml || null,
          expiry_date || null
        ]
      );
    }

    if (module_type === "arte") {
      await connection.query(
        `
        INSERT INTO arte (
          product_id,
          artist,
          technique,
          dimensions
        )
        VALUES (?, ?, ?, ?)
        `,
        [
          newId,
          artist || null,
          technique || null,
          dimensions || null
        ]
      );
    }

    await connection.commit();

    const [rows] = await db.query(
      `
      SELECT
        p.*,
        pl.scientific_name,
        COALESCE(pl.variety, co.variety) AS variety,
        pl.care,
        co.ingredients,
        co.weight_ml,
        co.expiry_date,
        ar.artist,
        ar.technique,
        ar.dimensions
      FROM products p
      LEFT JOIN plants pl ON pl.product_id = p.id
      LEFT JOIN conservas co ON co.product_id = p.id
      LEFT JOIN arte ar ON ar.product_id = p.id
      WHERE p.id = ?
      `,
      [newId]
    );

    res.status(201).json({
      message: "Producto creado correctamente",
      product: {
        ...rows[0],
        tags: parseMaybeJson(rows[0].tags)
      }
    });
  } catch (error) {
    await connection.rollback();

    if (error.message && error.message.includes("chk_products_stock")) {
      return res.status(400).json({
        error: "El stock no puede ser menor que 0"
      });
    }

    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

/* =========================================
   PRODUCT IMAGES
========================================= */
app.post("/products/:id/images", async (req, res) => {
  const { url, alt, display_order } = req.body;

  if (!url) {
    return res.status(400).json({ error: "La URL de imagen es obligatoria" });
  }

  try {
    const [productRows] = await db.query(
      "SELECT id FROM products WHERE id = ?",
      [req.params.id]
    );

    if (productRows.length === 0) {
      return res.status(404).json({ error: "Producto no encontrado" });
    }

    await db.query(
      `
      INSERT INTO product_images (product_id, url, alt, display_order)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        url = VALUES(url),
        alt = VALUES(alt)
      `,
      [
        req.params.id,
        url,
        alt || null,
        Number(display_order || 0)
      ]
    );

    const [rows] = await db.query(
      `
      SELECT id, product_id, url, alt, display_order, created_at
      FROM product_images
      WHERE product_id = ?
      ORDER BY display_order ASC, id ASC
      `,
      [req.params.id]
    );

    res.status(201).json({
      message: "Imagen agregada correctamente",
      images: rows
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* =========================================
   STOCK MOVEMENTS
========================================= */
app.get("/stock-movements/:productId", async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT id, product_id, movement_type, quantity, note, created_at
      FROM stock_movements
      WHERE product_id = ?
      ORDER BY created_at DESC, id DESC
      `,
      [req.params.productId]
    );

    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/stock-movements", async (req, res) => {
  const { product_id, movement_type, quantity, note } = req.body;

  if (
    !product_id ||
    !movement_type ||
    quantity === undefined ||
    quantity === null
  ) {
    return res.status(400).json({ error: "Faltan datos del movimiento" });
  }

  if (!["entrada", "salida", "ajuste"].includes(movement_type)) {
    return res.status(400).json({ error: "movement_type inválido" });
  }

  const numericQuantity = Number(quantity);

  if (!Number.isFinite(numericQuantity) || numericQuantity <= 0) {
    return res.status(400).json({ error: "Cantidad inválida" });
  }

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    const [productRows] = await connection.query(
      "SELECT id, stock FROM products WHERE id = ? FOR UPDATE",
      [product_id]
    );

    if (productRows.length === 0) {
      throw new Error("Producto no encontrado");
    }

    const currentStock = Number(productRows[0].stock);
    let newStock = currentStock;

    if (movement_type === "entrada") {
      newStock = currentStock + numericQuantity;
    } else if (movement_type === "salida") {
      if (currentStock < numericQuantity) {
        throw new Error("Stock insuficiente para la salida");
      }
      newStock = currentStock - numericQuantity;
    } else if (movement_type === "ajuste") {
      newStock = numericQuantity;
    }

    await connection.query(
      `
      INSERT INTO stock_movements (product_id, movement_type, quantity, note)
      VALUES (?, ?, ?, ?)
      `,
      [product_id, movement_type, numericQuantity, note || null]
    );

    await connection.query(
      `
      UPDATE products
      SET stock = ?, available = ?
      WHERE id = ?
      `,
      [newStock, newStock > 0 ? 1 : 0, product_id]
    );

    await connection.commit();

    res.status(201).json({
      message: "Movimiento registrado correctamente",
      stock: newStock
    });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

/* =========================================
   ORDERS
========================================= */
app.post("/orders", async (req, res) => {
  const { customer_name, customer_phone, customer_address, items } = req.body;

  if (
    !customer_name ||
    !customer_phone ||
    !customer_address ||
    !items ||
    !items.length
  ) {
    return res.status(400).json({ error: "Faltan datos para crear la orden" });
  }

  for (const item of items) {
    if (!item.product_id || !item.quantity || Number(item.quantity) <= 0) {
      return res.status(400).json({ error: "Items inválidos" });
    }
  }

  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    let total = 0;

    for (const item of items) {
      const [productRows] = await connection.query(
        "SELECT id, price, stock, active FROM products WHERE id = ?",
        [item.product_id]
      );

      if (productRows.length === 0) {
        throw new Error(`Producto no encontrado: ${item.product_id}`);
      }

      if (!productRows[0].active) {
        throw new Error(`Producto inactivo: ${item.product_id}`);
      }

      const itemQuantity = Number(item.quantity);
      const itemPrice = Number(productRows[0].price);
      const productStock = Number(productRows[0].stock);

      if (productStock < itemQuantity) {
        throw new Error(`Stock insuficiente para el producto: ${item.product_id}`);
      }

      total += itemPrice * itemQuantity;
    }

    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");
    const datePart = `${yyyy}${mm}${dd}`;

    const [countRows] = await connection.query(
      "SELECT COUNT(*) AS total FROM orders WHERE DATE(created_at) = CURDATE()"
    );

    const sequence = String(Number(countRows[0].total) + 1).padStart(3, "0");
    const orderNumber = `ORD-${datePart}-${sequence}`;

    const [orderResult] = await connection.query(
      `
      INSERT INTO orders (order_number, customer_name, customer_phone, customer_address, status, total)
      VALUES (?, ?, ?, ?, 'pending', ?)
      `,
      [orderNumber, customer_name, customer_phone, customer_address, total]
    );

    const orderId = orderResult.insertId;

    for (const item of items) {
      const [productRows] = await connection.query(
        "SELECT id, price, stock FROM products WHERE id = ? FOR UPDATE",
        [item.product_id]
      );

      const price = Number(productRows[0].price);
      const currentStock = Number(productRows[0].stock);
      const itemQuantity = Number(item.quantity);
      const newStock = currentStock - itemQuantity;

      await connection.query(
        `
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (?, ?, ?, ?)
        `,
        [orderId, item.product_id, itemQuantity, price]
      );

      await connection.query(
        `
        UPDATE products
        SET stock = ?, available = ?
        WHERE id = ?
        `,
        [newStock, newStock > 0 ? 1 : 0, item.product_id]
      );

      await connection.query(
        `
        INSERT INTO stock_movements (product_id, movement_type, quantity, note)
        VALUES (?, 'salida', ?, ?)
        `,
        [item.product_id, itemQuantity, `Salida por orden ${orderNumber}`]
      );
    }

    await connection.commit();

    res.status(201).json({
      message: "Orden creada correctamente",
      order_number: orderNumber,
      total
    });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.get("/orders", async (req, res) => {
  try {
    const [orders] = await db.query(`
      SELECT 
        id,
        order_number,
        customer_name,
        customer_phone,
        customer_address,
        status,
        total,
        created_at
      FROM orders
      ORDER BY created_at DESC
    `);

    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/orders/:id", async (req, res) => {
  try {
    const [orderRows] = await db.query(
      `
      SELECT 
        id,
        order_number,
        customer_name,
        customer_phone,
        customer_address,
        status,
        total,
        created_at
      FROM orders
      WHERE id = ?
      `,
      [req.params.id]
    );

    if (orderRows.length === 0) {
      return res.status(404).json({ error: "Pedido no encontrado" });
    }

    const [items] = await db.query(
      `
      SELECT 
        oi.id,
        oi.quantity,
        oi.price,
        p.id AS product_id,
        p.name,
        p.image_url,
        p.module_type
      FROM order_items oi
      INNER JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
      `,
      [req.params.id]
    );

    res.json({
      ...orderRows[0],
      items
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* =========================================
   ACTIVITIES
========================================= */
app.get("/activities", async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT id, title, description, activity_date, location, capacity, image_url, created_at
      FROM activities
      ORDER BY activity_date ASC
      `
    );

    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/activities", async (req, res) => {
  const {
    title,
    description,
    activity_date,
    location,
    capacity,
    image_url
  } = req.body;

  if (!title || !activity_date) {
    return res.status(400).json({
      error: "Título y fecha son obligatorios"
    });
  }

  try {
    const [result] = await db.query(
      `
      INSERT INTO activities
      (title, description, activity_date, location, capacity, image_url)
      VALUES (?, ?, ?, ?, ?, ?)
      `,
      [
        title,
        description || "",
        activity_date,
        location || "",
        Number(capacity || 0),
        image_url || ""
      ]
    );

    const [rows] = await db.query(
      "SELECT * FROM activities WHERE id = ?",
      [result.insertId]
    );

    res.status(201).json({
      message: "Actividad creada correctamente",
      activity: rows[0]
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* =========================================
   RECIPES
========================================= */
app.get("/recipes", async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT id, title, description, ingredients, steps, image_url, created_at
      FROM recipes
      ORDER BY created_at DESC
      `
    );

    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/recipes", async (req, res) => {
  const { title, description, ingredients, steps, image_url } = req.body;

  if (!title) {
    return res.status(400).json({ error: "El título es obligatorio" });
  }

  try {
    const [result] = await db.query(
      `
      INSERT INTO recipes (title, description, ingredients, steps, image_url)
      VALUES (?, ?, ?, ?, ?)
      `,
      [
        title,
        description || "",
        ingredients || "",
        steps || "",
        image_url || ""
      ]
    );

    const [rows] = await db.query(
      "SELECT * FROM recipes WHERE id = ?",
      [result.insertId]
    );

    res.status(201).json({
      message: "Receta creada correctamente",
      recipe: rows[0]
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

connectDB().then(() => {
  if (!db) {
    console.error("No se pudo conectar a la DB");
    process.exit(1);
  }

  app.listen(PORT, () => {
    console.log(`Servidor corriendo en puerto ${PORT}`);
  });
});
