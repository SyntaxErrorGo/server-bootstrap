# server-bootstrap

`server-bootstrap` — скрипт первичной настройки Linux-сервера (VPS) под Debian/Ubuntu.

Он помогает за один запуск:

- создать отдельного sudo-пользователя;
- настроить SSH-доступ по ключу, отключить root и вход по паролю;
- настроить часовой пояс и hostname;
- установить базовые утилиты (sudo, git, curl, htop и т.д.);
- включить UFW и открыть только нужные порты (SSH, HTTP, HTTPS).

Проект сделан как реальный DevOps / SysAdmin кейс для автоматизации «подготовки» сервера.

---

## Установка

```bash
git clone https://github.com/SyntaxErrorGo/server-bootstrap.git
cd server-bootstrap

chmod +x install.sh
sudo ./install.sh
