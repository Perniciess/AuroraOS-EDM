# SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
# SPDX-License-Identifier: BSD-3-Clause

import sqlite3

class Database:

	def __init__(self, database="db_doc.sqlite3"):
		self.database = database
		self.connection = None

	def connect(self):
		try:
			self.connection = sqlite3.connect(self.database)
			print("Успешное подключение к базе данных")
			self._init_table()
		except sqlite3.Error as e:
			print(f"Ошибка при подключении к базе данных: {e}")
			raise

	def _init_table(self):
		try:
			cursor = self.connection.cursor()
			cursor.execute("""
				CREATE TABLE IF NOT EXISTS File (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					file_name TEXT NOT NULL,
					file_status TEXT NOT NULL,
					file_path TEXT NOT NULL,
					certPath TEXT NOT NULL,
                    fileHash TEXT NOT NULL,
					created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
				)
			""")
			self.connection.commit()
			print("Проверка таблицы: OK")
		except sqlite3.Error as e:
			print(f"Ошибка при создании таблицы: {e}")
			raise

	def close(self):
		if self.connection:
			self.connection.close()
			self.connection = None
			print("Соединение с базой данных закрыто")

	def save_file(self, fileName, fileStatus, filePath, certPath, fileHash):
		if not self.connection:
			self.connect()
		try:
			cursor = self.connection.cursor()
			cursor.execute(
				"INSERT INTO File (file_name, file_status, file_path, certPath, fileHash) VALUES (?, ?, ?, ?, ?)",
				(fileName, fileStatus, str(filePath), str(certPath), str(fileHash))
			)
			self.connection.commit()
			status = True
		except sqlite3.Error as e:
			print(f"Ошибка при сохранении файла в БД: {e}")
			status = False

		self.close()
		return status

	def get_files_list(self):
		if not self.connection:
			self.connect()

		try:
			cursor = self.connection.cursor()
			cursor.execute("SELECT id, file_name, file_status, fileHash FROM File")
			documents = [
				{'id': row[0], 'file_name': row[1], 'file_status': row[2], 'fileHash': row[3]}
				for row in cursor.fetchall()
			]
		except sqlite3.Error as e:
			print("Ошибка при получении списка документов из базы данных")
			documents = []

		self.close()
		return documents


	def get_file_by_id(self, file_id):
		if not self.connection:
			self.connect()

		try:
			cursor = self.connection.cursor()
			cursor.execute("SELECT file_path FROM File WHERE id = ?", (file_id,))
			row = cursor.fetchone()
			if row:
				return {"file_path": row[0]}
		except sqlite3.Error as e:
			print(f"Ошибка при получении файла по ID: {e}")
			return None
		finally:
			self.close()

		return None
