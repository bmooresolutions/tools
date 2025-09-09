### docker-learning-assistant was made to teach me what BASH can do AND teach me a little about containers
### BMoore
#!/bin/bash

LOGFILE="docker_learning.log"

function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function explain() {
    echo ""
    echo "📘 $1"
    log "EXPLAIN: $1"
}

function quiz() {
    echo ""
    echo "🧠 Quick Quiz!"
    echo "$1"
    read -p "Your answer: " answer
    echo "✅ Great! Whether you're right or wrong, you're learning. Keep going!"
    log "QUIZ: $1 | Answer: $answer"
}

function apache_php_setup() {
    explain "Apache is a web server. PHP lets you run dynamic scripts. Together, they serve websites."
    read -p "Name your web container: " web_name
    read -p "Expose which port (e.g., 8080): " web_port

    docker pull php:8.2-apache
    docker run -d --name "$web_name" -p "$web_port":80 php:8.2-apache

    explain "Your container is running. Visit http://localhost:$web_port"
    explain "To add files: docker cp yourfile.php $web_name:/var/www/html/"
    quiz "What does the '-p' flag do in 'docker run -p 8080:80'?"
}

function mysql_setup() {
    explain "MySQL is a relational database. It stores structured data like users, posts, etc."
    read -p "Name your MySQL container: " db_name
    read -p "Set a root password: " db_pass

    docker pull mysql:8.0
    docker run -d --name "$db_name" -e MYSQL_ROOT_PASSWORD="$db_pass" -p 3306:3306 mysql:8.0

    explain "MySQL is running on port 3306. You can connect using a MySQL client."
    quiz "What does '-e MYSQL_ROOT_PASSWORD=...' do in the Docker command?"
}

function full_stack_setup() {
    explain "This setup links Apache+PHP with MySQL so your web app can store and retrieve data."
    read -p "Web container name: " web_name
    read -p "Web port: " web_port
    read -p "MySQL container name: " db_name
    read -p "MySQL root password: " db_pass

    docker pull php:8.2-apache
    docker pull mysql:8.0

    docker run -d --name "$db_name" -e MYSQL_ROOT_PASSWORD="$db_pass" mysql:8.0
    docker run -d --name "$web_name" --link "$db_name":mysql -p "$web_port":80 php:8.2-apache

    explain "Your full stack is live! Web server on port $web_port, database linked internally as 'mysql'."
    quiz "Why do we use '--link db_name:mysql' in the web container?"
}

function show_menu() {
    clear
    echo "======================================"
    echo "🚀 Docker Learning Assistant"
    echo "======================================"
    echo "Choose your learning path:"
    echo "1. Apache + PHP Web Server"
    echo "2. MySQL Database Server"
    echo "3. Full Stack (Apache + PHP + MySQL)"
    echo "4. View Log"
    echo "5. Exit"
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1) apache_php_setup ;;
        2) mysql_setup ;;
        3) full_stack_setup ;;
        4) cat "$LOGFILE" ;;
        5) echo "👋 See you next time, Docker wizard!" ; exit 0 ;;
        *) echo "❌ Invalid choice. Try again." ;;
    esac
}

# Main loop
while true; do
    show_menu
    echo ""
    read -p "Press Enter to return to the menu..."
done
