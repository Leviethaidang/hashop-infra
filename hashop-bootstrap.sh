#!/bin/bash -xe

exec > >(tee /var/log/hashop-bootstrap.log | logger -t hashop-bootstrap -s 2>/dev/console) 2>&1

source /opt/hashop/bootstrap.env

dnf update -y
dnf install -y git nginx mariadb105

curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

npm install -g pm2

systemctl enable nginx
systemctl start nginx

cd /home/ec2-user

git clone -b "$GIT_BRANCH" "$USER_SERVICE_REPO_URL" User-Service

chown -R ec2-user:ec2-user /home/ec2-user/User-Service

cat > /home/ec2-user/User-Service/.env <<EOF_ENV
PORT=3000
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$USER_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_SECRET=$USER_POOL_CLIENT_SECRET
EOF_ENV

chown ec2-user:ec2-user /home/ec2-user/User-Service/.env
chmod 600 /home/ec2-user/User-Service/.env

echo "Waiting for RDS..."
for n in $(seq 1 60); do
  if mysqladmin ping -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" --silent; then
    echo "RDS is ready"
    break
  fi

  echo "RDS not ready yet. Retry $n..."
  sleep 10
done

if [ -f "/home/ec2-user/User-Service/sql/init-user-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/User-Service/sql/init-user-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/User-Service && npm ci || npm install'

pm2 startup systemd -u ec2-user --hp /home/ec2-user || true
sudo -u ec2-user bash -lc 'cd /home/ec2-user/User-Service && pm2 delete user-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/User-Service && pm2 start server.js --name user-service'
sudo -u ec2-user bash -lc 'pm2 save'

cd /home/ec2-user
git clone -b "$GIT_BRANCH" "$PRODUCT_SERVICE_REPO_URL" Product-Service

chown -R ec2-user:ec2-user /home/ec2-user/Product-Service

cat > /home/ec2-user/Product-Service/.env <<EOF_PRODUCT_ENV
PORT=3001
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$PRODUCT_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID

S3_BUCKET_NAME=$PRODUCT_IMAGE_BUCKET_NAME
CLOUDFRONT_DOMAIN=$PRODUCT_CLOUDFRONT_DOMAIN

INVENTORY_SERVICE_URL=http://127.0.0.1:3002
INTERNAL_API_KEY=$INTERNAL_API_KEY
EOF_PRODUCT_ENV

chown ec2-user:ec2-user /home/ec2-user/Product-Service/.env
chmod 600 /home/ec2-user/Product-Service/.env

if [ -f "/home/ec2-user/Product-Service/sql/init-product-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/Product-Service/sql/init-product-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Product-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Product-Service && pm2 delete product-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Product-Service && pm2 start server.js --name product-service'
sudo -u ec2-user bash -lc 'pm2 save'

cd /home/ec2-user

git clone -b "$GIT_BRANCH" "$INVENTORY_SERVICE_REPO_URL" Inventory-Service

chown -R ec2-user:ec2-user /home/ec2-user/Inventory-Service

cat > /home/ec2-user/Inventory-Service/.env <<EOF_INVENTORY_ENV
PORT=3002
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$INVENTORY_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID

INTERNAL_API_KEY=$INTERNAL_API_KEY
EOF_INVENTORY_ENV

chown ec2-user:ec2-user /home/ec2-user/Inventory-Service/.env
chmod 600 /home/ec2-user/Inventory-Service/.env

if [ -f "/home/ec2-user/Inventory-Service/sql/init-inventory-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/Inventory-Service/sql/init-inventory-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Inventory-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Inventory-Service && pm2 delete inventory-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Inventory-Service && pm2 start server.js --name inventory-service'
sudo -u ec2-user bash -lc 'pm2 save'

cd /home/ec2-user
git clone -b "$GIT_BRANCH" "$CART_SERVICE_REPO_URL" Cart-Service

chown -R ec2-user:ec2-user /home/ec2-user/Cart-Service

cat > /home/ec2-user/Cart-Service/.env <<EOF_CART_ENV
PORT=3003
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$CART_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID

PRODUCT_SERVICE_URL=http://127.0.0.1:3001
INVENTORY_SERVICE_URL=http://127.0.0.1:3002

INTERNAL_API_KEY=$INTERNAL_API_KEY
EOF_CART_ENV

chown ec2-user:ec2-user /home/ec2-user/Cart-Service/.env
chmod 600 /home/ec2-user/Cart-Service/.env

if [ -f "/home/ec2-user/Cart-Service/sql/init-cart-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/Cart-Service/sql/init-cart-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Cart-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Cart-Service && pm2 delete cart-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Cart-Service && pm2 start server.js --name cart-service'
sudo -u ec2-user bash -lc 'pm2 save'

cd /home/ec2-user
git clone -b "$GIT_BRANCH" "$PAYMENT_SERVICE_REPO_URL" Payment-Service

chown -R ec2-user:ec2-user /home/ec2-user/Payment-Service

cat > /home/ec2-user/Payment-Service/.env <<EOF_PAYMENT_ENV
PORT=3005
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$PAYMENT_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID

PAYMENT_RESULT_TOPIC_ARN=$PAYMENT_RESULT_TOPIC_ARN
PAYMENT_REQUESTED_QUEUE_URL=$PAYMENT_REQUESTED_QUEUE_URL

INTERNAL_API_KEY=$INTERNAL_API_KEY
EOF_PAYMENT_ENV

chown ec2-user:ec2-user /home/ec2-user/Payment-Service/.env
chmod 600 /home/ec2-user/Payment-Service/.env

if [ -f "/home/ec2-user/Payment-Service/sql/init-payment-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/Payment-Service/sql/init-payment-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Payment-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Payment-Service && pm2 delete payment-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Payment-Service && pm2 start server.js --name payment-service'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Payment-Service && pm2 delete payment-worker || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Payment-Service && pm2 start worker.js --name payment-worker'

sudo -u ec2-user bash -lc 'pm2 save'

cd /home/ec2-user

git clone -b "$GIT_BRANCH" "$ORDER_SERVICE_REPO_URL" Order-Service

chown -R ec2-user:ec2-user /home/ec2-user/Order-Service

cat > /home/ec2-user/Order-Service/.env <<EOF_ORDER_ENV
PORT=3004
AWS_REGION=$AWS_REGION

DB_HOST=$DB_ENDPOINT
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$ORDER_DB_NAME

COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_APP_CLIENT_ID=$USER_POOL_CLIENT_ID
COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID

USER_SERVICE_URL=http://127.0.0.1:3000
PRODUCT_SERVICE_URL=http://127.0.0.1:3001
INVENTORY_SERVICE_URL=http://127.0.0.1:3002
CART_SERVICE_URL=http://127.0.0.1:3003
PAYMENT_SERVICE_URL=http://127.0.0.1:3005

PAYMENT_REQUESTED_TOPIC_ARN=$PAYMENT_REQUESTED_TOPIC_ARN
PAYMENT_RESULT_QUEUE_URL=$PAYMENT_RESULT_QUEUE_URL

NOTIFICATION_REQUESTED_TOPIC_ARN=$NOTIFICATION_REQUESTED_TOPIC_ARN

INTERNAL_API_KEY=$INTERNAL_API_KEY
EOF_ORDER_ENV

chown ec2-user:ec2-user /home/ec2-user/Order-Service/.env
chmod 600 /home/ec2-user/Order-Service/.env

if [ -f "/home/ec2-user/Order-Service/sql/init-order-db.sql" ]; then
  mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" < /home/ec2-user/Order-Service/sql/init-order-db.sql
fi

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Order-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Order-Service && pm2 delete order-service || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Order-Service && pm2 start server.js --name order-service'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Order-Service && pm2 delete order-worker || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Order-Service && pm2 start worker.js --name order-worker'

sudo -u ec2-user bash -lc 'pm2 save'


cd /home/ec2-user

git clone -b "$GIT_BRANCH" "$NOTIFICATION_SERVICE_REPO_URL" Notification-Service

chown -R ec2-user:ec2-user /home/ec2-user/Notification-Service

cat > /home/ec2-user/Notification-Service/.env <<EOF_NOTIFICATION_ENV
AWS_REGION=$AWS_REGION

NOTIFICATION_REQUESTED_QUEUE_URL=$NOTIFICATION_REQUESTED_QUEUE_URL

ADMIN_EMAIL=$ADMIN_EMAIL
SES_FROM_EMAIL=$SES_FROM_EMAIL
EOF_NOTIFICATION_ENV

chown ec2-user:ec2-user /home/ec2-user/Notification-Service/.env
chmod 600 /home/ec2-user/Notification-Service/.env

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Notification-Service && npm ci || npm install'

sudo -u ec2-user bash -lc 'cd /home/ec2-user/Notification-Service && pm2 delete notification-worker || true'
sudo -u ec2-user bash -lc 'cd /home/ec2-user/Notification-Service && pm2 start worker.js --name notification-worker'

sudo -u ec2-user bash -lc 'pm2 save'

mkdir -p /var/www/hashop

git clone -b "$GIT_BRANCH" "$FRONTEND_REPO_URL" Front-end
cp -r /home/ec2-user/Front-end/* /var/www/hashop/ || true

mkdir -p /var/www/hashop/assets/js

cat > /var/www/hashop/assets/js/config.js <<'EOF_CONFIG'
window.APP_CONFIG = {
    USER_SERVICE_URL: "",
    PRODUCT_SERVICE_URL: "",
    INVENTORY_SERVICE_URL: "",
    CART_SERVICE_URL: "",
    ORDER_SERVICE_URL: "",
    PAYMENT_SERVICE_URL: ""
};
EOF_CONFIG

chown -R nginx:nginx /var/www/hashop || true

rm -f /etc/nginx/conf.d/default.conf

cat > /etc/nginx/conf.d/hashop.conf <<'EOF_NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/hashop;
    index index.html;

    location = /index.html {
        return 302 /;
    }

    location = /login.html {
        return 302 /login;
    }

    location = /register.html {
        return 302 /register;
    }

    location = /profile.html {
        return 302 /profile;
    }

    location = /edit-profile.html {
        return 302 /profile/edit;
    }

    location = /admin-users.html {
        return 302 /admin/users;
    }

    location = /admin-products.html {
        return 302 /admin/products;
    }

    location = /admin-categories.html {
        return 302 /admin/categories;
    }

    location = /cart.html {
        return 302 /cart;
    }

    location = /confirm-order.html {
        return 302 /confirm-order/cart;
    }

    location = /orders.html {
        return 302 /orders;
    }

    location = /order-detail.html {
        return 302 /orders;
    }

    location = /admin-orders.html {
        return 302 /admin/orders;
    }

    location = / {
        try_files /index.html =404;
    }

    location ^~ /products/ {
        try_files /product-detail.html =404;
    }

    location = /login {
        try_files /login.html =404;
    }

    location = /register {
        try_files /register.html =404;
    }

    location = /profile {
        try_files /profile.html =404;
    }

    location = /profile/edit {
        try_files /edit-profile.html =404;
    }

    location = /admin/users {
        try_files /admin-users.html =404;
    }

    location = /admin/products {
        try_files /admin-products.html =404;
    }

    location = /admin/categories {
        try_files /admin-categories.html =404;
    }
    
    location = /cart {
        try_files /cart.html =404;
    }

    location = /confirm-order {
        try_files /confirm-order.html =404;
    }

    location = /confirm-order/cart {
        try_files /confirm-order.html =404;
    }

    location = /confirm-order/buy-now {
        try_files /confirm-order.html =404;
    }

    location = /orders {
        try_files /orders.html =404;
    }

    location ^~ /orders/ {
        try_files /order-detail.html =404;
    }

    location = /admin/orders {
        try_files /admin-orders.html =404;
    }

    location ~ ^/api/(inventory|cart|orders|payments)/internal(/|$) {
        return 404;
    }

    location /api/users {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/products {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/categories {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/sizes {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/colors {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/inventory {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/cart {
        proxy_pass http://127.0.0.1:3003;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/orders {
        proxy_pass http://127.0.0.1:3004;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/payments {
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }

    location /api/ {
        return 404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF_NGINX

nginx -t
systemctl reload nginx

echo "HaShop Full Service bootstrap completed"