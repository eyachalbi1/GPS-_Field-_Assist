import sys
sys.path.insert(0, 'src')
from models.database import get_db, hash_password

admins = [
    ("admin",    "admin123"),
    ("manager",  "manager123"),
]

with get_db() as conn:
    with conn.cursor() as cur:
        for username, password in admins:
            cur.execute("""
                INSERT INTO users (username, password, role)
                VALUES (%s, %s, 'admin')
                ON CONFLICT (username) DO UPDATE
                SET password = EXCLUDED.password, role = 'admin'
                RETURNING id, username, role
            """, (username, hash_password(password)))
            row = cur.fetchone()
            print(f"OK  id={row['id']}  username={row['username']}  role={row['role']}")
        conn.commit()

print("\nComptes admin créés avec succès!")
print("admin    / admin123")
print("manager  / manager123")
