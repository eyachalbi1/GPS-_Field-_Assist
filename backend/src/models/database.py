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

def init_users_table():
    with get_db() as conn:
        with conn.cursor() as cursor:            # Create tables only if missing to avoid deleting existing users.
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(20) UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    role TEXT NOT NULL,
                    date_de_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Créer la table des tâches
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    reference VARCHAR(20) UNIQUE NOT NULL,
                    name VARCHAR(100) NOT NULL,
                    description TEXT,
                    partner_name VARCHAR(100),
                    start_time VARCHAR(10),
                    end_time VARCHAR(10),
                    status VARCHAR(20) DEFAULT 'a_faire',
                    user_id INTEGER REFERENCES users(id),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            admin_password = pwd_context.hash("admin123")
            cursor.execute("""
                INSERT INTO users (username, password, role)
                VALUES (%s, %s, %s)
                ON CONFLICT (username) DO NOTHING
            """, ("admin", admin_password, "admin"))

            # Insérer des tâches de test
            cursor.execute("""
                INSERT INTO tasks (reference, name, description, partner_name, start_time, end_time, status, user_id)
                SELECT 'REF-001', 'Installation GPS', 'Installation GPS véhicule client A', 'Partenaire Alpha', '12h', '13h', 'a_faire', id FROM users WHERE username = 'admin'
                UNION ALL
                SELECT 'REF-002', 'Maintenance GPS', 'Maintenance système GPS', 'Partenaire Beta', '14h', '16h', 'a_faire', id FROM users WHERE username = 'admin'
                UNION ALL
                SELECT 'REF-003', 'Diagnostic', 'Diagnostic technique', 'Partenaire Gamma', '11h', '12h', 'en_cours', id FROM users WHERE username = 'admin'
                UNION ALL
                SELECT 'REF-004', 'Configuration', 'Configuration dispositif', 'Partenaire Delta', '14h', '16h', 'termine', id FROM users WHERE username = 'admin'
                ON CONFLICT (reference) DO NOTHING
            """)

            conn.commit()

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_tasks_by_user(user_id: int):
    """Récupérer toutes les tâches d'un utilisateur"""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, reference, name, description, partner_name,
                       start_time, end_time, status
                FROM tasks
                WHERE user_id = %s
                ORDER BY created_at DESC
            """, (user_id,))
            return [dict(row) for row in cursor.fetchall()]

def update_task_status_db(task_id: str, status: str, user_id: int):
    """Mettre à jour le statut d'une tâche"""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE tasks
                SET status = %s
                WHERE id = %s AND user_id = %s
            """, (status, task_id, user_id))
            return cursor.rowcount > 0

def get_all_users():
    """Récupérer tous les utilisateurs"""
    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, username, role, date_de_creation
                FROM users
                ORDER BY date_de_creation DESC
            """)
            return [dict(row) for row in cursor.fetchall()]

def add_test_users():
    """Ajouter des utilisateurs de test"""
    test_users = [
        ("technicien1", "tech123", "technicien"),
        ("technicien2", "tech123", "technicien"),
        ("admin2", "admin123", "admin"),
        ("superviseur", "super123", "admin"),
    ]

    with get_db() as conn:
        with conn.cursor() as cursor:
            for username, password, role in test_users:
                hashed_password = pwd_context.hash(password)
                cursor.execute("""
                    INSERT INTO users (username, password, role)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (username) DO NOTHING
                """, (username, hashed_password, role))
            conn.commit()

def add_user(username: str, password: str, role: str):
    """Ajouter un utilisateur spécifique"""
    if role not in ['admin', 'technicien']:
        raise ValueError("Le rôle doit être 'admin' ou 'technicien'")

    if len(username) > 20:
        raise ValueError("Le nom d'utilisateur ne peut pas dépasser 20 caractères")

    hashed_password = pwd_context.hash(password)

    with get_db() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO users (username, password, role)
                VALUES (%s, %s, %s)
                ON CONFLICT (username) DO UPDATE SET
                    password = EXCLUDED.password,
                    role = EXCLUDED.role
            """, (username, hashed_password, role))
            conn.commit()
            return cursor.rowcount > 0


