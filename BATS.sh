#!/bin/bash

# BATS - Bonus Apache Tool Set

function show_menu() {
    echo "===== BATS: Bonus Apache Tool Set ====="
    echo "1) View Apache error logs"
    echo "2) Run journalctl -xe"
    echo "3) Create new Apache site"
    echo "4) List available/enabled Apache sites"
    echo "5) Enable an Apache site"
    echo "6) Disable an Apache site"
    echo "7) Restart Apache"
    echo "0) Exit"
    echo "======================================="
    read -p "Choose an option: " choice
    handle_choice "$choice"
}

function handle_choice() {
    case "$1" in
        1) tail -n 50 /var/log/apache2/error.log ;;
        2) journalctl -xe ;;
        3) create_apache_site ;;
        4) list_sites ;;
        5) read -p "Enter site name to enable: " site; sudo a2ensite "$site"; sudo systemctl reload apache2 ;;
        6) read -p "Enter site name to disable: " site; sudo a2dissite "$site"; sudo systemctl reload apache2 ;;
        7) sudo systemctl restart apache2 ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option. Try again." ;;
    esac
    echo ""
    read -p "Press Enter to continue..." dummy
    clear
    show_menu
}

function create_apache_site() {
    read -p "Enter site name (e.g., mysite): " sitename
    read -p "Enter domain name (e.g., mysite.local): " domain
    read -p "Enter document root (e.g., /var/www/mysite): " docroot

    conf_path="/etc/apache2/sites-available/${sitename}.conf"

    sudo bash -c "cat > $conf_path" <<EOF
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot $docroot

    <Directory $docroot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${sitename}_error.log
    CustomLog \${APACHE_LOG_DIR}/${sitename}_access.log combined
</VirtualHost>
EOF

    echo "Site config created at $conf_path"
    echo "Don't forget to create the document root and enable the site:"
    echo "  sudo mkdir -p $docroot"
    echo "  sudo a2ensite ${sitename}.conf"
    echo "  sudo systemctl reload apache2"
}

function list_sites() {
    echo "Available sites:"
    ls /etc/apache2/sites-available
    echo ""
    echo "Enabled sites:"
    ls /etc/apache2/sites-enabled
}

# Start the tool
clear
show_menu
