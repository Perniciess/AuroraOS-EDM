TARGET = ru.auroraos.ElectronicDocumentManagement


QT = core network dbus websockets


CONFIG += \
    auroraapp \
    auroraapp_i18n\

PKGCONFIG += openssl

SOURCES += \
    src/main.cpp \
    src/pdf/dbusadaptor.cpp \
    src/pdf/fileinfo.cpp \
    src/pdf/filesmodel.cpp \
    src/pdf/trackerqueryworker.cpp \
    src/pdf/sortmodel.cpp \
    src/pdf/applicationsettings.cpp \
    src/signature/digitalsignature.cpp \
    src/signature/cryptomanager.cpp \
    src/database/database.cpp \
    src/websocket/websocket.cpp \
    src/config/config.cpp \


HEADERS += \
    src/pdf/dbusadaptor.hpp \
    src/pdf/dbusconstants.hpp \
    src/pdf/fileinfo.hpp \
    src/pdf/filesmodel.hpp \
    src/pdf/trackerqueryworker.hpp \
    src/pdf/sortmodel.hpp \
    src/pdf/applicationsettings.hpp \
    src/signature/digitalsignature.hpp \
    src/signature/cryptomanager.hpp \
    src/database/database.hpp \
    src/websocket/websocket.hpp \
    src/config/config.hpp \


DISTFILES += \
    rpm/ru.auroraos.ElectronicDocumentManagement.spec \
    AUTHORS.md \
    README.md \
    LICENSE \


AURORAAPP_ICONS = 86x86 108x108 128x128 172x172


TRANSLATIONS += \
    translations/ru.auroraos.ElectronicDocumentManagement.ts \
    translations/ru.auroraos.ElectronicDocumentManagement-ru.ts \
