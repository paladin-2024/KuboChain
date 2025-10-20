const express = require('express');
const mysql = require('mysql2');
const app = express();
const PORT = 3000;


app.use(express.json());

const connection = mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: 'Mamanlucie1906@@',
    database: 'Blockchain'
});

connection.connect(err => {
    if (err) {
        console.error('Error connecting to MySQL:', err);
        process.exit(1);
    }
    console.log('Connected to MySQL');
});

const bcrypt = require('bcrypt');

app.post('/signup', async (req, res) => {
    const { username, password, name } = req.body;

    if (!username || !password || !name) {
        return res.status(400).json({ message: 'Username and password required' });
    }

    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        const query = 'INSERT INTO Blockchain (username, password, name) VALUES (?, ?, ?)';
        const testQuery = 'SELECT * FROM Blockchain WHERE username = ? || name = ?';
        if (testQuery) {
            return res.status(409).json({message : 'Username or name already exists'})
        } else {
        connection.query(query, [username, hashedPassword, name], (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'Internal server error' });
            }

            return res.status(201).json({ message: 'User created', userId: results.insertId });
        });
    }
    } catch (err) {
        console.error('Hashing error:', err);
        res.status(500).json({ message: 'Error creating user' });
    }
});


app.post('/signup', (req, res) => {
    const { username, password, name } = req.body;

    if (!username || !password || !name) {
        return res.status(400).json({ message: 'Username, password and name are required' });
    }

    const query = 'INSERT INTO Blockchain (Username, Password, Name) VALUES (?, ?, ?)';
    connection.query(query, [username, password, name], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'Internal server error' });
        }

        return res.status(201).json({ message: 'User created', userId: results.insertId });
    });
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
