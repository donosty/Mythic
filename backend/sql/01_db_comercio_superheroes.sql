-- ============================================================
--  BASE DE DATOS: Tienda de Coleccionables de Superhéroes
--  Motor: PostgreSQL
-- ============================================================

-- ─────────────────────────────────────────────
--  TIPOS ENUMERADOS
-- ─────────────────────────────────────────────

CREATE TYPE condicion_producto   AS ENUM ('nuevo', 'usado', 'restaurado');
CREATE TYPE estado_envio_tipo    AS ENUM ('pendiente', 'preparando', 'en_camino', 'entregado', 'devuelto', 'cancelado');
CREATE TYPE estado_pago_tipo     AS ENUM ('pendiente', 'completado', 'rechazado', 'reembolsado');
CREATE TYPE estado_venta_tipo    AS ENUM ('pendiente', 'confirmada', 'enviada', 'completada', 'cancelada');
CREATE TYPE tipo_movimiento      AS ENUM ('entrada', 'salida', 'ajuste', 'devolucion');
CREATE TYPE metodo_pago_tipo     AS ENUM ('tarjeta_credito', 'tarjeta_debito', 'transferencia', 'efectivo', 'paypal', 'crypto');
CREATE TYPE tipo_coleccionable   AS ENUM ('figura_accion', 'estatua', 'busto', 'funko_pop', 'comic', 'poster', 'ropa', 'accesorio', 'replica', 'otro');
CREATE TYPE universo_tipo        AS ENUM ('marvel', 'dc', 'dark_horse', 'image', 'independiente', 'otro');


-- ─────────────────────────────────────────────
--  CUENTAS
-- ─────────────────────────────────────────────

CREATE TABLE cuentas (
    id_cuenta           SERIAL          PRIMARY KEY,
    nombre_usuario      VARCHAR(100)    NOT NULL UNIQUE,
    correo              VARCHAR(150)    NOT NULL UNIQUE,
    contrasena          VARCHAR(255)    NOT NULL,           -- hash bcrypt/argon2
    fecha_creacion      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    ultimo_login        TIMESTAMPTZ,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);


-- ─────────────────────────────────────────────
--  CLIENTES
-- ─────────────────────────────────────────────

CREATE TABLE clientes (
    id_cliente          SERIAL          PRIMARY KEY,
    id_cuenta           INT             NOT NULL UNIQUE REFERENCES cuentas(id_cuenta) ON DELETE CASCADE,
    nombre              VARCHAR(100)    NOT NULL,
    apellido            VARCHAR(100)    NOT NULL,
    telefono            VARCHAR(20),
    fecha_nacimiento    DATE,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);


-- ─────────────────────────────────────────────
--  DIRECCIONES
-- ─────────────────────────────────────────────

CREATE TABLE direcciones (
    id_direccion        SERIAL          PRIMARY KEY,
    calle               VARCHAR(150)    NOT NULL,
    num_ext             VARCHAR(10)     NOT NULL,
    num_int             VARCHAR(10),
    colonia             VARCHAR(100),
    codigo_postal       VARCHAR(10)     NOT NULL,
    municipio           VARCHAR(100)    NOT NULL,
    estado              VARCHAR(100)    NOT NULL,
    pais                VARCHAR(80)     NOT NULL DEFAULT 'México',
    referencias         VARCHAR(255)                        -- ej. "portón azul"
);

CREATE TABLE clientes_direcciones (
    id_cliente          INT             NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    id_direccion        INT             NOT NULL REFERENCES direcciones(id_direccion) ON DELETE CASCADE,
    alias               VARCHAR(60),                        -- ej. "casa", "oficina"
    es_predeterminada   BOOLEAN         NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_cliente, id_direccion)
);


-- ─────────────────────────────────────────────
--  UNIVERSOS Y FRANQUICIAS
-- ─────────────────────────────────────────────

CREATE TABLE universos (
    id_universo         SERIAL          PRIMARY KEY,
    nombre              VARCHAR(100)    NOT NULL UNIQUE,    -- "Marvel 616", "DC New 52", etc.
    editorial           universo_tipo   NOT NULL,
    descripcion         TEXT
);

CREATE TABLE franquicias (
    id_franquicia       SERIAL          PRIMARY KEY,
    id_universo         INT             NOT NULL REFERENCES universos(id_universo),
    nombre              VARCHAR(100)    NOT NULL,           -- "X-Men", "Avengers", "Justice League"
    descripcion         TEXT
);

CREATE TABLE personajes (
    id_personaje        SERIAL          PRIMARY KEY,
    id_franquicia       INT             REFERENCES franquicias(id_franquicia),
    nombre_heroe        VARCHAR(100)    NOT NULL,           -- "Spider-Man"
    nombre_real         VARCHAR(100),                       -- "Peter Parker"
    descripcion         TEXT
);


-- ─────────────────────────────────────────────
--  FABRICANTES
-- ─────────────────────────────────────────────

CREATE TABLE fabricantes (
    id_fabricante       SERIAL          PRIMARY KEY,
    nombre              VARCHAR(100)    NOT NULL,           -- "Hot Toys", "Sideshow", "Hasbro"
    pais_origen         VARCHAR(80),
    sitio_web           VARCHAR(255),
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);


-- ─────────────────────────────────────────────
--  CATEGORÍAS Y PRODUCTOS
-- ─────────────────────────────────────────────

CREATE TABLE categorias (
    id_categoria        SERIAL          PRIMARY KEY,
    nombre              VARCHAR(100)    NOT NULL UNIQUE,
    tipo_coleccionable  tipo_coleccionable NOT NULL,
    descripcion         TEXT
);

CREATE TABLE productos (
    id_producto         SERIAL          PRIMARY KEY,
    id_categoria        INT             NOT NULL REFERENCES categorias(id_categoria),
    id_fabricante       INT             REFERENCES fabricantes(id_fabricante),
    nombre              VARCHAR(150)    NOT NULL,
    descripcion         TEXT,
    condicion           condicion_producto NOT NULL DEFAULT 'nuevo',
    escala              VARCHAR(20),                        -- "1/6", "1/4", "1:1"
    altura_cm           NUMERIC(6,2),                       -- altura de la figura en cm
    peso_g              INT,                                -- peso en gramos (útil para envíos)
    precio              NUMERIC(10,2)   NOT NULL CHECK (precio >= 0),
    stock               INT             NOT NULL DEFAULT 0 CHECK (stock >= 0),
    es_edicion_limitada BOOLEAN         NOT NULL DEFAULT FALSE,
    tiraje_total        INT,                                -- null = sin límite
    numero_serie        VARCHAR(50),                        -- para piezas numeradas
    fecha_lanzamiento   DATE,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);

-- Relación producto ↔ personaje (un producto puede representar varios personajes)
CREATE TABLE productos_personajes (
    id_producto         INT             NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    id_personaje        INT             NOT NULL REFERENCES personajes(id_personaje) ON DELETE CASCADE,
    PRIMARY KEY (id_producto, id_personaje)
);

CREATE TABLE producto_imagenes (
    id_imagen           SERIAL          PRIMARY KEY,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    url_imagen          VARCHAR(500)    NOT NULL,
    es_principal        BOOLEAN         NOT NULL DEFAULT FALSE,
    orden               SMALLINT        NOT NULL DEFAULT 0
);

CREATE TABLE producto_etiquetas (
    id_producto         INT             NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    etiqueta            VARCHAR(60)     NOT NULL,           -- "hot-toys", "primera-edicion", "exclusivo"
    PRIMARY KEY (id_producto, etiqueta)
);


-- ─────────────────────────────────────────────
--  INVENTARIO
-- ─────────────────────────────────────────────

CREATE TABLE inventario_movimientos (
    id_movimiento       SERIAL          PRIMARY KEY,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto),
    tipo                tipo_movimiento NOT NULL,
    cantidad            INT             NOT NULL,           -- positivo o negativo según tipo
    stock_resultante    INT             NOT NULL,
    fecha               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    motivo              VARCHAR(255),
    id_usuario          INT             REFERENCES cuentas(id_cuenta)  -- quién registró
);


-- ─────────────────────────────────────────────
--  CARRITO
-- ─────────────────────────────────────────────

CREATE TABLE carritos (
    id_carrito          SERIAL          PRIMARY KEY,
    id_cliente          INT             NOT NULL UNIQUE REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    actualizado_en      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE carritos_detalle (
    id_carrito          INT             NOT NULL REFERENCES carritos(id_carrito) ON DELETE CASCADE,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto),
    cantidad            INT             NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    agregado_en         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_carrito, id_producto)
);


-- ─────────────────────────────────────────────
--  LISTA DE DESEOS (Wishlist)
-- ─────────────────────────────────────────────

CREATE TABLE wishlists (
    id_wishlist         SERIAL          PRIMARY KEY,
    id_cliente          INT             NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    nombre              VARCHAR(100)    NOT NULL DEFAULT 'Mi lista de deseos',
    publica             BOOLEAN         NOT NULL DEFAULT FALSE
);

CREATE TABLE wishlists_detalle (
    id_wishlist         INT             NOT NULL REFERENCES wishlists(id_wishlist) ON DELETE CASCADE,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto),
    agregado_en         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_wishlist, id_producto)
);


-- ─────────────────────────────────────────────
--  CUPONES Y DESCUENTOS
-- ─────────────────────────────────────────────

CREATE TABLE cupones (
    id_cupon            SERIAL          PRIMARY KEY,
    codigo              VARCHAR(50)     NOT NULL UNIQUE,
    descripcion         VARCHAR(255),
    descuento_pct       NUMERIC(5,2)    CHECK (descuento_pct BETWEEN 0 AND 100),
    descuento_fijo      NUMERIC(10,2)   CHECK (descuento_fijo >= 0),
    monto_minimo        NUMERIC(10,2)   DEFAULT 0,
    usos_maximos        INT,
    usos_actuales       INT             NOT NULL DEFAULT 0,
    fecha_inicio        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    fecha_fin           TIMESTAMPTZ,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT cupon_tipo CHECK (
        (descuento_pct IS NOT NULL AND descuento_fijo IS NULL) OR
        (descuento_pct IS NULL AND descuento_fijo IS NOT NULL)
    )
);


-- ─────────────────────────────────────────────
--  VENTAS
-- ─────────────────────────────────────────────

CREATE TABLE ventas (
    id_venta            SERIAL          PRIMARY KEY,
    id_cliente          INT             NOT NULL REFERENCES clientes(id_cliente),
    id_cupon            INT             REFERENCES cupones(id_cupon),
    fecha_venta         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    status              estado_venta_tipo NOT NULL DEFAULT 'pendiente',
    subtotal            NUMERIC(10,2)   NOT NULL CHECK (subtotal >= 0),
    descuento           NUMERIC(10,2)   NOT NULL DEFAULT 0 CHECK (descuento >= 0),
    impuesto            NUMERIC(10,2)   NOT NULL DEFAULT 0 CHECK (impuesto >= 0),   -- IVA 16 %
    total               NUMERIC(10,2)   NOT NULL CHECK (total >= 0),
    notas               TEXT
);

CREATE TABLE ventas_detalle (
    id_venta_detalle    SERIAL          PRIMARY KEY,
    id_venta            INT             NOT NULL REFERENCES ventas(id_venta) ON DELETE CASCADE,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto),
    cantidad            INT             NOT NULL CHECK (cantidad > 0),
    precio_unitario     NUMERIC(10,2)   NOT NULL CHECK (precio_unitario >= 0),
    subtotal_linea      NUMERIC(10,2)   GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);


-- ─────────────────────────────────────────────
--  FACTURAS
-- ─────────────────────────────────────────────

CREATE TABLE facturas (
    id_factura          SERIAL          PRIMARY KEY,
    id_venta            INT             NOT NULL UNIQUE REFERENCES ventas(id_venta),
    folio               VARCHAR(50)     NOT NULL UNIQUE,    -- folio fiscal SAT
    uuid_cfdi           UUID            UNIQUE,
    rfc_receptor        VARCHAR(20)     NOT NULL,
    razon_social        VARCHAR(255)    NOT NULL,
    regimen_fiscal      VARCHAR(100),
    uso_cfdi            VARCHAR(10),
    fecha_timbrado      TIMESTAMPTZ,
    url_pdf             VARCHAR(500),
    url_xml             VARCHAR(500),
    cancelada           BOOLEAN         NOT NULL DEFAULT FALSE
);


-- ─────────────────────────────────────────────
--  ENVÍOS
-- ─────────────────────────────────────────────

CREATE TABLE envios (
    id_envio            SERIAL          PRIMARY KEY,
    id_venta            INT             NOT NULL UNIQUE REFERENCES ventas(id_venta),
    id_direccion        INT             NOT NULL REFERENCES direcciones(id_direccion),
    paqueteria          VARCHAR(100),                       -- "DHL", "FedEx", "Estafeta"
    numero_guia         VARCHAR(100),
    costo_envio         NUMERIC(10,2)   NOT NULL DEFAULT 0,
    fecha_envio         TIMESTAMPTZ,
    fecha_estimada      TIMESTAMPTZ,
    fecha_entrega       TIMESTAMPTZ,
    estado_envio        estado_envio_tipo NOT NULL DEFAULT 'pendiente',
    notas               TEXT
);


-- ─────────────────────────────────────────────
--  PAGOS
-- ─────────────────────────────────────────────

CREATE TABLE pagos (
    id_pago             SERIAL          PRIMARY KEY,
    id_venta            INT             NOT NULL REFERENCES ventas(id_venta),
    metodo_pago         metodo_pago_tipo NOT NULL,
    monto               NUMERIC(10,2)   NOT NULL CHECK (monto > 0),
    referencia_externa  VARCHAR(255),                       -- ID de transacción Stripe/PayPal
    fecha_pago          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    estado_pago         estado_pago_tipo NOT NULL DEFAULT 'pendiente'
);


-- ─────────────────────────────────────────────
--  RESEÑAS DE PRODUCTOS
-- ─────────────────────────────────────────────

CREATE TABLE resenas (
    id_resena           SERIAL          PRIMARY KEY,
    id_producto         INT             NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    id_cliente          INT             NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    calificacion        SMALLINT        NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    titulo              VARCHAR(150),
    comentario          TEXT,
    fecha               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    verificada          BOOLEAN         NOT NULL DEFAULT FALSE,  -- compró el producto
    UNIQUE (id_producto, id_cliente)
);


-- ─────────────────────────────────────────────
--  ÍNDICES PARA RENDIMIENTO
-- ─────────────────────────────────────────────

CREATE INDEX idx_productos_categoria    ON productos(id_categoria);
CREATE INDEX idx_productos_fabricante   ON productos(id_fabricante);
CREATE INDEX idx_productos_activo       ON productos(activo);
CREATE INDEX idx_ventas_cliente         ON ventas(id_cliente);
CREATE INDEX idx_ventas_status          ON ventas(status);
CREATE INDEX idx_ventas_fecha           ON ventas(fecha_venta);
CREATE INDEX idx_ventas_detalle_venta   ON ventas_detalle(id_venta);
CREATE INDEX idx_ventas_detalle_prod    ON ventas_detalle(id_producto);
CREATE INDEX idx_inventario_producto    ON inventario_movimientos(id_producto);
CREATE INDEX idx_resenas_producto       ON resenas(id_producto);
CREATE INDEX idx_pagos_venta            ON pagos(id_venta);
