# Electronic Document Management
This project is a document management application using an electronic digital signature

The main purpose is to demonstrate using a minimum of source code to get a correct and extensible application.

# Terms of Use and Participation
The source code of the project is provided under the [BSD-3-Clause license](LICENSE), which allows its use in third-party applications.

The [contributor agreement](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/CONTRIBUTING.md?ref_type=heads) documents the rights granted by contributors of the Open Mobile Platform.?

Information about the contributors is specified in the [AUTHORS](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/AUTHORS.md?ref_type=heads) file.

[Code of conduct](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/CODE_OF_CONDUCT.md) is a current set of rules of the Open Mobile
Platform which informs you how we expect the members of the community will interact
while contributing and communicating.?

# Project structure
The project has a common structure of an application based on C++ and QML for Aurora OS.

- **[client](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/)** the directory containing the client implementation of the application
	- **[application](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application?ref_type=heads)** directory contains the application
		- **[ru.auroraos.ElectronicDocumentManagement.pro](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/client/application/ru.auroraos.ElectronicDocumentManagement.pro?ref_type=heads)** file
		describes the project structure for the qmake build system.
		- **[icons](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/icons?ref_type=heads)** directory      contains the application icons for different screen resolutions.
		- **[qml](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml?ref_type=heads)** directory contains the QML source code and the UI resources.
			- **[assets](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml/assets?ref_type=heads)** the directory contains additional user interface icons.
			- **[components](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml/components?ref_type=heads)** directory contains the custom UI components.
			- **[cover](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml/cover?ref_type=heads)** directory contains the application cover implementations.
			- **[icons](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml/icons?ref_type=heads)** directory contains the additional custom UI icons.
			- **[pages](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/qml/pages?ref_type=heads)** directory contains the application pages.
			- **[ElectronicDocumentManagement.qml](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/client/application/qml/ru.auroraos.ElectronicDocumentManagement.qml?ref_type=heads)** file provides the application window implementation.
		- **[rpm](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/rpm?ref_type=heads)** directory contains the rpm-package build settings.
			- **[ru.auroraos.ElectronicDocumentManagement.spec](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/client/application/rpm/ru.auroraos.ElectronicDocumentManagement.spec?ref_type=heads)** file is used by rpmbuild tool.
		- **[src](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/src?ref_type=heads)** directory contains the C++ source code.
			- **[database](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/src/database?ref_type=heads)** directory contains the database-client implementation
			- **[pdf](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/src/pdf?ref_type=heads)** directory contains the pdf implementation
			- **[signature](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/src/signature?ref_type=heads)** directory contains the electronic digital signature implementation
			- **[websocket](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/src/websocket?ref_type=heads)** directory contains the websocket-client implementatio
			- **[main.cpp](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/client/application/src/main.cpp?ref_type=heads)** file is the application entry point.
		- **[translations](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/client/application/translations?ref_type=heads)** directory contains the UI translation files.
		- **[ru.auroraos.ElectronicDocumentManagement.desktop](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/client/application/ru.auroraos.ElectronicDocumentManagement.desktop?ref_type=heads)** file
		defines the display and parameters for launching the application.
- **[server](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/server?ref_type=heads)** the directory containing the server implementation of the application
	- **[database](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/server/database?ref_type=heads)** directory contains the database-server implementation
	- **[websocket](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/tree/signature/server/websocket?ref_type=heads)** directory containts the websocket-server implementation
	- **[main.py](https://gitlab.com/mobiledevelopment2025/workshop/2b_1_document_flow/-/blob/signature/server/main.py?ref_type=heads)** file is the entry point to the server application.

# Compatibility
The project is compatible with all the supported versions of the Aurora OS.

# Installation and assembly
The project is assembled in the usual way using the Aurora SDK.

# Starting the server

1. Make sure that you have python version 3.13 installed (this version was used during development).
2. Open a terminal or command prompt.
3. Navigate to the directory where the server source code should be located.
4. Copy the repository.
5. Run the `cd 2b_1_document_flow` command.
6. Run the `rm -r client CODE_OF_CONDUCT.md CONTRIBUTING.md README.md README.ru.md` to delete files that are unnecessary for the server. Keep `LICENSE` and `AUTHORS.md` with the source code.
7. Run the `cd server` command.
8. Run the `python3 -m venv .venv` command to initialize the Python virtual environment.
9. Run the `source .venv/bin/activate` command to activate the Python virtual environment.
10. Run the `pip install -r requirements.txt` command to install the necessary dependencies.
11. Run the `python3 main.py` command to start the server.

# Functional
The application has been tested for compliance with the following functionality:
- The application displays a list of documents on the device.
- The application allows you to view pdf documents.
- The application displays the document statuses ("Not viewed", "Viewed", "Signed", "Processed").
- The application changes the file statuses with appropriate actions.
- The application allows you to sign a document with an electronic signature.
- The application allows you to send a signed file to the server over a WebSocket Secure connection.
- The application allows you to get a list of files from the server.
- The application allows you to download a file from the server to the device.
- The application does not display the file located on the server if it is already on the device.
