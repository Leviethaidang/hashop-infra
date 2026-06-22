const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    console.log("Cognito Event Received:", JSON.stringify(event, null, 2));

    const userId = event.request.userAttributes.sub;
    const email = event.request.userAttributes.email;
    const phoneNumber = event.request.userAttributes.phone_number || null;
    const fullName = event.request.userAttributes.name || 'New User';
    const address = null;
    
    const dbConfig = {
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: 'ecommerce_user_db',
        port: 3306
    };

    let connection;

    try {
        connection = await mysql.createConnection(dbConfig);

        const query = `
            INSERT INTO users (
                user_id,
                full_name,
                email,
                phone_number,
                default_shipping_address
            )
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                full_name = VALUES(full_name),
                email = VALUES(email),
                phone_number = VALUES(phone_number),
                updated_at = CURRENT_TIMESTAMP;
        `;

        await connection.execute(query, [
            userId,
            fullName,
            email,
            phoneNumber,
            address
        ]);

        console.log(`Đã đồng bộ user ${userId} vào RDS Database thành công!`);

    } catch (error) {
        console.error("Lỗi khi ghi vào Database:", error);
        throw error;
    } finally {
        if (connection) await connection.end();
    }

    return event;
};