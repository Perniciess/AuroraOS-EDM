# Описание приложения
Приложение Aurora OS, позволяющее необходимый функционал для работы с документами в электронном виде с использованием цифровой подписи.

Основная цель - продемонстрировать, как с помощью минимума исходного кода можно получить корректное и расширяемое приложение.

# Условия использования и участия
Исходный код проекта предоставляется по [лицензии BSD-3-Clause](LICENSE), которая позволяет использовать его в сторонних приложениях.

Соглашение участника [(документ на английском)](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/CONTRIBUTING.md?ref_type=heads) регламентирует права,
предоставляемые участниками компании «Открытая Мобильная Платформа».

Информация об участниках указана в файле [AUTHORS](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/AUTHORS.md?ref_type=heads).

Кодекс поведения  [(документ на английском)](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/CODE_OF_CONDUCT.md) — это действующий набор
правил компании «Открытая Мобильная Платформа», который информирует об ожиданиях по
взаимодействию между членами сообщества при общении и работе над проектами.

# Структура проекта
Проект имеет стандартную структуру приложения на базе C++ и QML для ОС Аврора.

- Каталог **[client](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/)** содержит клиентскую реализацию приложения.
	- Каталог **[application](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application?ref_type=heads)** содержит исходный код приложения
		- Файл **[ru.auroraos.ElectronicDocumentManagement.pro](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/client/application/ru.auroraos.ElectronicDocumentManagement.pro?ref_type=heads)** описывает структура проекта для системы сборки qmake.
		- Каталог **[icons](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/icons?ref_type=heads)** содержит иконки приложения для поддерживаемых разрешений экрана.
		- Каталог **[qml](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml?ref_type=heads)** содержит исходный код на QML и ресурсы интерфейса пользователя.
			- Каталог **[assets](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml/assets?ref_type=heads)** содержит дополнительные значки пользовательского интерфейса.
			- Каталог **[components](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml/components?ref_type=heads)** содержит пользовательские компоненты пользовательского интерфейса.
			- Каталог **[cover](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml/cover?ref_type=heads)** содержит реализации обложек приложения.
			- Каталог **[icons](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml/icons?ref_type=heads)** содержит дополнительные иконки интерфейса пользователя.
			- Каталог **[pages](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/qml/pages?ref_type=heads)** содержит страницы приложения.
			- Файл **[ElectronicDocumentManagement.qml](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/client/application/qml/ru.auroraos.ElectronicDocumentManagement.qml?ref_type=heads)** предоставляет реализацию окна приложения.
		- Каталог **[rpm](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/rpm?ref_type=heads)** содержит настройки сборки rpm-пакета.
			- Файл **[ru.auroraos.ElectronicDocumentManagement.spec](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/client/application/rpm/ru.auroraos.ElectronicDocumentManagement.spec?ref_type=heads)** используется инструментом rpmbuild.
		- Каталог **[src](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/src?ref_type=heads)** содержит исходный код на C++.
			- Каталог **[database](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/src/database?ref_type=heads)** содержит клиентскую реализацию базы данных
			- Каталог **[pdf](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/src/pdf?ref_type=heads)** содержит реализацию работы с pdf-файлами.
			- Каталог **[main](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/src/main?ref_type=heads)** содержит реализацию работы с ЭЦП.
			- Каталог **[websocket](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/src/websocket?ref_type=heads)** содержит реализацию работы с вебсокетом.
			- Файл **[main.cpp](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/client/application/src/main.cpp?ref_type=heads)** является точкой входа в приложение.
		- Каталог **[translations](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/client/application/translations?ref_type=heads)** содержит файлы перевода интерфейса пользователя.
		- Файл **[ru.auroraos.ElectronicDocumentManagement.desktop](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/client/application/ru.auroraos.ElectronicDocumentManagement.desktop?ref_type=heads)** определяет отображение и параметры запуска приложения.
- Каталог **[server](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/server?ref_type=heads)** содержит исходный код сервера.
	- Каталог **[database](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/server/database?ref_type=heads)** содержит реализацию базы данных на сервере.
	- Каталог **[websocket](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/main/server/websocket?ref_type=heads)** содержит реализацию работы с вебсокетом.
	- Файл **[main.py](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/main/server/main.py?ref_type=heads)** является точкой входа в серверное приложение.

# Совместимость
Проект совместим с актуальными версиями ОС Аврора.

# Установка и сборка
Проект собирается обычным образом с помощью Аврора SDK.

# Запуск сервера

1. Убедитесь, что у вас установлен python версии 3.13 (данная версия использовалась при разработке).
2. Откройте терминал или командную строку.
3. Перейдите в каталог, в котором должен будет находится исходный код сервера.
4. Скопируйте репозиторий.
5. Выполните команду `cd 2b_1_document_flow`.
6. Выполните команду `rm -r client CODE_OF_CONDUCT.md CONTRIBUTING.md README.md README.ru.md`, чтобы удалить ненужные для сервера файлы. Сохраните `LICENSE` и `AUTHORS.md` вместе с исходным кодом.
7. Выполните команду `cd server`.
8. Выполните команду `python3 -m venv .venv`, чтобы инициализировать виртуальное окружение Python.
9. Выполните команду `source .venv/bin/activate`, чтобы активировать виртуальное окружение Python.
10. Выполните команду `pip install -r requirements.txt`, чтобы установить необходимые зависимости.
11. Выполните команду `python3 main.py`, чтобы запустить сервер.

# Функционал
Приложение было протестировано на соответствие следующему функционалу:
- Приложение отображает список документов, находящихся на устройстве.
- Приложение позволяет просматривать pdf документы.
- Приложение отображает статусы документов ("Не просмотрено", "Просмотрено", "Подписано", "Обработано").
- Приложение меняет статусы файлов при соответствующих действиях.
- Приложение позволяет подписать документ электронной подписью.
- Приложение позволяет отправить подписанный файл на сервер по WebSocket Secure соединению.
- Приложение позволяет получить список файлов с сервера.
- Приложение позволяет скачать файл с сервера на устройство.
- Приложение не отображает файл, находящийся на сервере, если он уже есть на устройстве.
