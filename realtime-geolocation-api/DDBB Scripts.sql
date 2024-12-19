-- Crear la tabla 'users' para almacenar información de los usuarios
CREATE TABLE users (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    email VARCHAR2(255) UNIQUE,
    phone_number VARCHAR2(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear la tabla 'assets' para almacenar información de los activos
CREATE TABLE assets (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    type VARCHAR2(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear la tabla 'locations' para almacenar ubicaciones en tiempo real de usuarios o activos
CREATE TABLE locations (
    id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    latitude NUMBER(9,6) NOT NULL,
    longitude NUMBER(9,6) NOT NULL,
    altitude NUMBER(9,6),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    location SDO_GEOMETRY,  -- Geometría espacial para almacenar la ubicación
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Crear índice espacial para mejorar el rendimiento de las consultas geoespaciales
CREATE INDEX idx_location_geom ON locations(location) INDEXTYPE IS MDSYS.SPATIAL_INDEX;

-- Crear la tabla 'location_history' para almacenar el historial de ubicaciones
CREATE TABLE location_history (
    id NUMBER PRIMARY KEY,
    entity_id NUMBER NOT NULL,  -- Puede ser un 'user_id' o 'asset_id'
    entity_type VARCHAR2(10) CHECK (entity_type IN ('user', 'asset')),
    latitude NUMBER(9,6) NOT NULL,
    longitude NUMBER(9,6) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    location SDO_GEOMETRY,  -- Ubicación espacial
    CONSTRAINT fk_entity FOREIGN KEY (entity_id) REFERENCES users(id) 
                             ON DELETE CASCADE  -- Relación con la tabla de usuarios
);

-- Crear la tabla 'routes' para almacenar rutas entre ubicaciones
CREATE TABLE routes (
    id NUMBER PRIMARY KEY,
    start_location SDO_GEOMETRY,  -- Punto de inicio de la ruta
    end_location SDO_GEOMETRY,  -- Punto de fin de la ruta
    distance NUMBER(10,2),  -- Distancia en kilómetros
    duration NUMBER(10,2),  -- Duración en minutos
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear índices espaciales para las rutas
CREATE INDEX idx_routes_start_geom ON routes(start_location) INDEXTYPE IS MDSYS.SPATIAL_INDEX;
CREATE INDEX idx_routes_end_geom ON routes(end_location) INDEXTYPE IS MDSYS.SPATIAL_INDEX;

-- Crear una función para calcular la distancia entre dos puntos geoespaciales
CREATE OR REPLACE FUNCTION calculate_distance(
    p_lat1 IN NUMBER,
    p_lon1 IN NUMBER,
    p_lat2 IN NUMBER,
    p_lon2 IN NUMBER
) RETURN NUMBER IS
    v_point1 MDSYS.SDO_GEOMETRY;
    v_point2 MDSYS.SDO_GEOMETRY;
    v_distance NUMBER;
BEGIN
    -- Crear los puntos geoespaciales
    v_point1 := MDSYS.SDO_GEOMETRY(2001, NULL, NULL, MDSYS.SDO_ELEM_INFO_ARRAY(1, 1, 1), MDSYS.SDO_ORDINATE_ARRAY(p_lon1, p_lat1));
    v_point2 := MDSYS.SDO_GEOMETRY(2001, NULL, NULL, MDSYS.SDO_ELEM_INFO_ARRAY(1, 1, 1), MDSYS.SDO_ORDINATE_ARRAY(p_lon2, p_lat2));

    -- Calcular la distancia en metros
    v_distance := SDO_GEOM.SDO_DISTANCE(v_point1, v_point2, 0.005);

    RETURN v_distance;
END;

-- Crear un trigger para insertar en 'location_history' cada vez que se inserte o actualice una ubicación en la tabla 'locations'
CREATE OR REPLACE TRIGGER trg_location_update
AFTER INSERT OR UPDATE ON locations
FOR EACH ROW
BEGIN
    INSERT INTO location_history (entity_id, entity_type, latitude, longitude, timestamp, location)
    VALUES (
        :NEW.user_id,  -- O 'asset_id' dependiendo de la entidad
        'user',  -- 'user' o 'asset'
        :NEW.latitude,
        :NEW.longitude,
        SYSDATE,
        :NEW.location
    );
END;
