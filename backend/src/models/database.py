# src/models/database.py
import psycopg2
from psycopg2.extras import RealDictCursor
from passlib.context import CryptContext
import os
from dotenv import load_dotenv

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "tunav_gps_tracking_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "password"),
    "port": os.getenv("DB_PORT", "5432"),
    "client_encoding": "utf8"
}

def get_db():
    return psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

def init_users_table():
    with get_db() as conn:
        with conn.cursor() as cursor:
            # Table users — utilise les nouveaux noms de colonnes
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    assigned_to_name VARCHAR(50) UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    role TEXT NOT NULL,
                    assigned_to_id VARCHAR(50),
                    date_de_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Table tasks
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    reference VARCHAR(50) UNIQUE,
                    name VARCHAR(200) NOT NULL,
                    description TEXT,
                    partner_name VARCHAR(200),
                    start_time VARCHAR(20),
                    end_time VARCHAR(20),
                    status VARCHAR(30) DEFAULT 'a_faire',
                    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Créer l'admin par défaut s'il n'existe pas
            admin_password = pwd_context.hash("admin123")
            cursor.execute("""
                INSERT INTO users (assigned_to_name, password, role)
                VALUES (%s, %s, %s)
                ON CONFLICT (assigned_to_name) DO NOTHING
            """, ("admin", admin_password, "admin"))

            conn.commit()

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_tasks_by_user(user_id: int):
    """Récupérer les tâches assignées à un utilisateur via la FK assigned_to_id."""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    t.id::text          AS id,
                    COALESCE(t.subject, t.name, '')  AS subject,
                    COALESCE(t.description, '')      AS description,
                    COALESCE(t.partner_name, '')     AS partner_name,
                    COALESCE(t.start_time, '')       AS start_time,
                    COALESCE(t.end_time, '')         AS end_time,
                    COALESCE(t.stage, t.status, 'a_faire') AS stage,
                    COALESCE(t.assigned_to, u.assigned_to_name, '') AS assigned_to,
                    t.created_at::text               AS created_at
                FROM tasks t
                LEFT JOIN users u ON u.id = t.assigned_to_id
                WHERE t.assigned_to_id = %s
                ORDER BY t.created_at DESC
            """, (user_id,))
            return [dict(row) for row in cursor.fetchall()]

def update_task_status_db(task_id: str, status: str, user_id: int):
    """Mettre à jour le stage d'une tâche."""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE tasks SET stage = %s
                WHERE id = %s AND assigned_to_id = %s
            """, (status, task_id, user_id))
            conn.commit()
            return cursor.rowcount > 0

def get_all_users():
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, assigned_to_name AS username, role, date_de_creation
                FROM users
                ORDER BY date_de_creation DESC
            """)
            return [dict(row) for row in cursor.fetchall()]


def add_test_users():
    test_users = [
        ("technicien1", "tech123", "technicien"),
        ("technicien2", "tech123", "technicien"),
        ("admin2",      "admin123", "admin"),
        ("superviseur", "super123", "admin"),
    ]
    with get_db() as conn:
        with conn.cursor() as cursor:
            for uname, password, role in test_users:
                cursor.execute("""
                    INSERT INTO users (assigned_to_name, password, role)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (assigned_to_name) DO NOTHING
                """, (uname, pwd_context.hash(password), role))
            conn.commit()


def add_user(username: str, password: str, role: str):
    if role not in ['admin', 'technicien']:
        raise ValueError("Le rôle doit être 'admin' ou 'technicien'")
    if len(username) > 20:
        raise ValueError("Le nom d'utilisateur ne peut pas dépasser 20 caractères")
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO users (assigned_to_name, password, role)
                VALUES (%s, %s, %s)
                ON CONFLICT (assigned_to_name) DO UPDATE SET
                    password = EXCLUDED.password,
                    role = EXCLUDED.role
            """, (username, pwd_context.hash(password), role))
            conn.commit()
            return cursor.rowcount > 0
