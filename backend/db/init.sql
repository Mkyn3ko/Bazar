-- =========================================
-- USUARIOS
-- =========================================
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  role ENUM('user', 'admin') NOT NULL DEFAULT 'user',
  failed_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_email (email),
  INDEX idx_users_locked (locked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users (name, email, password, role)
VALUES ('Administrador', 'admin@bazar.com', 'admin123', 'admin')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  role = VALUES(role);

-- =========================================
-- SESIONES
-- =========================================
CREATE TABLE IF NOT EXISTS user_sessions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(255) NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  INDEX idx_sessions_user (user_id),
  INDEX idx_sessions_token (token_hash),
  INDEX idx_sessions_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- CATEGORIAS
-- =========================================
CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO categories (name, description)
VALUES
  ('Interior', 'Plantas para espacios interiores con poca luz'),
  ('Exterior', 'Plantas para jardin y terraza'),
  ('Suculentas', 'Suculentas y cactus de bajo riego'),
  ('Aromaticas', 'Hierbas aromaticas y medicinales'),
  ('Arboles', 'Arboles y arbustos'),
  ('Conservas', 'Mermeladas y productos de despensa'),
  ('Arte', 'Obras artisticas y decoracion')
ON DUPLICATE KEY UPDATE
  description = VALUES(description);

-- =========================================
-- PRODUCTOS
-- =========================================
CREATE TABLE IF NOT EXISTS products (
  id CHAR(36) PRIMARY KEY,
  module_type ENUM('plant', 'conserva', 'arte') NOT NULL,
  category_id INT NULL,

  name VARCHAR(200) NOT NULL,
  subtitle VARCHAR(200) NULL,
  description TEXT NULL,
  tags JSON NULL,
  unit VARCHAR(30) NOT NULL DEFAULT 'unidad',

  price INT UNSIGNED NULL,
  stock INT NOT NULL DEFAULT 0,
  available BOOLEAN NOT NULL DEFAULT TRUE,
  active BOOLEAN NOT NULL DEFAULT TRUE,

  image_url TEXT NULL,
  image_alt VARCHAR(255) NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT chk_products_stock CHECK (stock >= 0),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(id)
    ON DELETE SET NULL,

  INDEX idx_products_category (category_id),
  INDEX idx_products_available (available),
  INDEX idx_products_stock (stock),
  INDEX idx_products_active (active),
  INDEX idx_products_module_type (module_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- PLANTAS
-- =========================================
CREATE TABLE IF NOT EXISTS plants (
  product_id CHAR(36) PRIMARY KEY,
  scientific_name VARCHAR(200) NULL,
  variety VARCHAR(100) NULL,
  care TEXT NULL,
  CONSTRAINT fk_plants_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- CONSERVAS
-- =========================================
CREATE TABLE IF NOT EXISTS conservas (
  product_id CHAR(36) PRIMARY KEY,
  variety VARCHAR(100) NULL,
  ingredients TEXT NULL,
  weight_ml VARCHAR(50) NULL,
  expiry_date DATE NULL,
  CONSTRAINT fk_conservas_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- ARTE
-- =========================================
CREATE TABLE IF NOT EXISTS arte (
  product_id CHAR(36) PRIMARY KEY,
  artist VARCHAR(150) NULL,
  technique VARCHAR(100) NULL,
  dimensions VARCHAR(80) NULL,
  CONSTRAINT fk_arte_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- IMAGENES ADICIONALES
-- =========================================
CREATE TABLE IF NOT EXISTS product_images (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id CHAR(36) NOT NULL,
  url TEXT NOT NULL,
  alt VARCHAR(255),
  display_order SMALLINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_images_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_product_image_order (product_id, display_order),
  INDEX idx_product_images_product (product_id, display_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- MOVIMIENTOS DE STOCK
-- =========================================
CREATE TABLE IF NOT EXISTS stock_movements (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  product_id CHAR(36) NOT NULL,
  user_id INT NULL,
  movement_type ENUM('entrada', 'salida', 'ajuste') NOT NULL,
  quantity INT NOT NULL,
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_stock_movements_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_stock_movements_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE SET NULL,
  INDEX idx_stock_movements_product (product_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- ACTIVIDADES
-- =========================================
CREATE TABLE IF NOT EXISTS activities (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  activity_date DATETIME NOT NULL,
  location VARCHAR(150),
  capacity INT NOT NULL DEFAULT 0,
  image_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_activities_title_date (title, activity_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- RECETAS
-- =========================================
CREATE TABLE IF NOT EXISTS recipes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  ingredients TEXT,
  steps TEXT,
  image_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_recipes_title (title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- ORDENES
-- =========================================
CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(50) NOT NULL UNIQUE,
  customer_name VARCHAR(150) NOT NULL,
  customer_phone VARCHAR(50) NOT NULL,
  customer_address VARCHAR(255) NOT NULL,
  status ENUM('pending','confirmed','shipped','delivered','cancelled') NOT NULL DEFAULT 'pending',
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- ITEMS DE ORDENES
-- =========================================
CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id CHAR(36) NOT NULL,
  quantity INT NOT NULL,
  price INT UNSIGNED NULL,
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- DATOS: PLANTAS
-- =========================================
INSERT INTO products (
  id, module_type, category_id, name, description, unit,
  price, stock, available, image_url, image_alt, tags, active
)
VALUES
(
  '69e86a53-f526-429b-89c8-1f0fc655de81',
  'plant',
  1,
  'Monstera',
  'Planta tropical de gran tamano.',
  'unidad',
  6000,
  12,
  TRUE,
  'http://localhost:4000/img/mostera.jpg',
  'Monstera deliciosa',
  JSON_ARRAY('interior','tropical','decorativa'),
  TRUE
),
(
  '4efa5dc3-77ef-42cd-beaa-0b277e037cfc',
  'plant',
  3,
  'Echeveria',
  'Suculenta de roseta perfecta.',
  'unidad',
  3500,
  10,
  TRUE,
  'http://localhost:4000/img/echeveria.jpg',
  'Echeveria elegans',
  JSON_ARRAY('suculenta','bajo_riego','interior'),
  TRUE
),
(
  '2cf3fc4f-a2a0-4d00-bf3f-82dd352da046',
  'plant',
  1,
  'Helecho Boston',
  'Helecho frondoso para interiores.',
  'unidad',
  4000,
  8,
  TRUE,
  'http://localhost:4000/img/helecho.jpg',
  'Helecho Boston',
  JSON_ARRAY('interior','humedad','sombra'),
  TRUE
)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  price = VALUES(price),
  stock = VALUES(stock),
  image_url = VALUES(image_url),
  tags = VALUES(tags);

INSERT INTO plants (product_id, scientific_name, variety, care)
VALUES
(
  '69e86a53-f526-429b-89c8-1f0fc655de81',
  'Monstera deliciosa',
  NULL,
  'Luz indirecta brillante. Regar cuando el sustrato este seco en la parte superior.'
),
(
  '4efa5dc3-77ef-42cd-beaa-0b277e037cfc',
  'Echeveria elegans',
  NULL,
  'Requiere mucha luz y bajo riego. Evitar exceso de humedad.'
),
(
  '2cf3fc4f-a2a0-4d00-bf3f-82dd352da046',
  'Nephrolepis exaltata',
  NULL,
  'Prefiere humedad ambiental y luz indirecta. Mantener el sustrato ligeramente humedo.'
)
ON DUPLICATE KEY UPDATE
  scientific_name = VALUES(scientific_name),
  variety = VALUES(variety),
  care = VALUES(care);

INSERT INTO product_images (product_id, url, alt, display_order)
VALUES
(
  '69e86a53-f526-429b-89c8-1f0fc655de81',
  'http://localhost:4000/img/monstera_2.jpg',
  'Monstera detalle hoja',
  1
)
ON DUPLICATE KEY UPDATE
  url = VALUES(url),
  alt = VALUES(alt);

-- =========================================
-- DATOS: CONSERVAS
-- =========================================
INSERT INTO products (
  id, module_type, category_id, name, description, unit,
  price, stock, available, image_url, image_alt, tags, active
)
VALUES
(
  '0d0abc92-49b2-49bd-ae92-d897942acc6e',
  'conserva',
  6,
  'Mermelada Ciruela',
  'Elaborada con ciruelas de la temporada y azucar blanca.',
  'unidad',
  4000,
  15,
  TRUE,
  'http://localhost:4000/img/m_ciruela.jpg',
  'Mermelada de ciruela artesanal',
  JSON_ARRAY('mermelada','artesanal','sin_conservantes'),
  TRUE
),
(
  '8168168a-324e-44ce-8ae7-39a77e845b90',
  'conserva',
  6,
  'Mermelada de Higo',
  'Elaborada con higos de temporada y azucar blanca.',
  'unidad',
  4500,
  5,
  TRUE,
  'http://localhost:4000/img/mermelada_higo.jpg',
  'Mermelada de higo artesanal',
  JSON_ARRAY('mermelada','artesanal','sin_conservantes'),
  TRUE
),
(
  '8cec43f8-9e79-4a1a-822e-bde4f027fff7',
  'conserva',
  6,
  'Mermelada Aji y Manzana',
  'Perfecta para acompanar quesos y carnes.',
  'unidad',
  7500,
  10,
  TRUE,
  'http://localhost:4000/img/ajiymanzana.jpg',
  'Mermelada de aji y manzana artesanal',
  JSON_ARRAY('mermelada','artesanal','sin_conservantes'),
  TRUE
)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  price = VALUES(price),
  stock = VALUES(stock),
  image_url = VALUES(image_url),
  tags = VALUES(tags);

INSERT INTO conservas (product_id, variety, ingredients, weight_ml, expiry_date)
VALUES
(
  '0d0abc92-49b2-49bd-ae92-d897942acc6e',
  'Ciruela Negra',
  'Ciruelas y azucar',
  '500ml',
  NULL
),
(
  '8168168a-324e-44ce-8ae7-39a77e845b90',
  'Higo',
  'Higos y azucar',
  '250ml',
  NULL
),
(
  '8cec43f8-9e79-4a1a-822e-bde4f027fff7',
  'Aji Rojo y Manzana Roja',
  'Aji rojo, manzana roja, azucar',
  '200ml',
  NULL
)
ON DUPLICATE KEY UPDATE
  variety = VALUES(variety),
  ingredients = VALUES(ingredients),
  weight_ml = VALUES(weight_ml),
  expiry_date = VALUES(expiry_date);

-- =========================================
-- DATOS: ARTE
-- =========================================
INSERT INTO products (
  id, module_type, category_id, name, description, unit,
  price, stock, available, image_url, image_alt, tags, active
)
VALUES
(
  'a4cb8153-51cf-4fce-904d-282e34cbd709',
  'arte',
  7,
  'Raices',
  'Obra abstracta inspirada en las raices de los arboles centenarios.',
  'unidad',
  350000,
  1,
  TRUE,
  'http://localhost:4000/img/raices.jpg',
  'Cuadro raices acrilico madera',
  JSON_ARRAY('acrilico','abstracto','madera'),
  TRUE
),
(
  'dfb06e3c-ba8e-4c21-a674-2de53ba99aff',
  'arte',
  7,
  'Jardin en Calma',
  'Paisaje botanico de jardin mediterraneo con luz de atardecer.',
  'unidad',
  280000,
  1,
  TRUE,
  'http://localhost:4000/img/jardin_calma.jpg',
  'Cuadro jardin en calma',
  JSON_ARRAY('oleo','paisaje','botanico'),
  TRUE
),
(
  'ed28b6cb-e636-49f9-addb-661f9fa7ccef',
  'arte',
  7,
  'Flores Silvestres No.3',
  'Serie de flores silvestres en tecnica acuarela edicion numerada.',
  'unidad',
  15000,
  4,
  TRUE,
  'http://localhost:4000/img/flores_silvestres.jpg',
  'Acuarela flores silvestres',
  JSON_ARRAY('acuarela','flores','edicion_limitada'),
  TRUE
)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  price = VALUES(price),
  stock = VALUES(stock),
  image_url = VALUES(image_url),
  tags = VALUES(tags);

INSERT INTO arte (product_id, artist, technique, dimensions)
VALUES
(
  'a4cb8153-51cf-4fce-904d-282e34cbd709',
  'Carlos Mendoza',
  'Acrilico sobre madera',
  '50x50 cm'
),
(
  'dfb06e3c-ba8e-4c21-a674-2de53ba99aff',
  'Maria Solis',
  'Oleo sobre lienzo',
  '60x80 cm'
),
(
  'ed28b6cb-e636-49f9-addb-661f9fa7ccef',
  'Maria Solis',
  'Acuarela sobre papel',
  '30x40 cm'
)
ON DUPLICATE KEY UPDATE
  artist = VALUES(artist),
  technique = VALUES(technique),
  dimensions = VALUES(dimensions);

-- =========================================
-- DATOS: MOVIMIENTOS DE STOCK
-- =========================================
INSERT INTO stock_movements (product_id, user_id, movement_type, quantity, note)
VALUES
(
  '69e86a53-f526-429b-89c8-1f0fc655de81',
  NULL,
  'entrada',
  12,
  'Stock inicial'
),
(
  '4efa5dc3-77ef-42cd-beaa-0b277e037cfc',
  NULL,
  'entrada',
  10,
  'Stock inicial'
),
(
  '2cf3fc4f-a2a0-4d00-bf3f-82dd352da046',
  NULL,
  'entrada',
  8,
  'Stock inicial'
);

-- =========================================
-- DATOS: ACTIVIDADES
-- =========================================
INSERT INTO activities (title, description, activity_date, location, capacity, image_url)
VALUES
(
  'Taller de suculentas',
  'Aprende a trasplantar y cuidar suculentas en casa.',
  '2026-05-10 16:00:00',
  'San Javier',
  20,
  'http://localhost:4000/img/taller_suculentas.jpg'
),
(
  'Encuentro de jardineria',
  'Actividad practica de cuidado y mantencion de plantas de interior.',
  '2026-05-18 11:00:00',
  'Huerto Creativo',
  15,
  'http://localhost:4000/img/jardineria.jpg'
)
ON DUPLICATE KEY UPDATE
  description = VALUES(description),
  location = VALUES(location),
  capacity = VALUES(capacity),
  image_url = VALUES(image_url);

-- =========================================
-- DATOS: RECETAS
-- =========================================
INSERT INTO recipes (title, description, ingredients, steps, image_url)
VALUES
(
  'Tostadas con mermelada de higo',
  'Una receta simple para desayuno o brunch.',
  'Pan de campo\nMermelada de higo\nQueso crema',
  'Tostar el pan.\nUntar queso crema.\nAgregar mermelada de higo encima.',
  'http://localhost:4000/img/tostadas_higo.jpg'
),
(
  'Tabla de quesos con mermelada aji y manzana',
  'Acompanamiento ideal para reuniones.',
  'Quesos variados\nMermelada aji y manzana\nGalletas saladas',
  'Servir los quesos en tabla.\nAgregar la mermelada en un recipiente pequeno.\nAcompanar con galletas.',
  'http://localhost:4000/img/tabla_quesos.jpg'
)
ON DUPLICATE KEY UPDATE
  description = VALUES(description),
  ingredients = VALUES(ingredients),
  steps = VALUES(steps),
  image_url = VALUES(image_url);