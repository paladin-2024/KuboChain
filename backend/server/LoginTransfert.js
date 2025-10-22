const express = require('express');
const mongoose = require('mongoose');
const app = express();
const PORT = 3000;

mongoose.connect('mongodb://localhost:27017/mydatabase', {
    useNewUrlParser:true,
    useUnifiedTopology:true
})
.then(() => console.log('Connected to MongoDB'))
.catch(err => console.error('MongoDB connection error:', err));

const userSchema = new mongoose.Schema({
    username: String,
    email: String,
    password: String
})

const User = mongoose.model('User', userSchema);

const newUser = new User(userSchema);
newUser.save()
.then(() => console.log('User saved'))
.catch(err => console.error(err));


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