const express = require('express');
const { MongoClient } = require('mongodb');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
    origin: [
        'http://localhost:3000',
        'http://flutter_backend:3000',
        // Add any other origins where your Flutter web app runs
    ],
    credentials: true
}));
app.use(express.json());

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DATABASE_NAME = process.env.DATABASE_NAME || 'n8n_worksheets';
const COLLECTION_NAME = process.env.COLLECTION_NAME || 'worksheets';

let db;
let collection;

// Connect to MongoDB
async function connectToMongoDB() {
  try {
    const client = new MongoClient(MONGODB_URI);
    await client.connect();
    console.log('Connected to MongoDB successfully');
    
    db = client.db(DATABASE_NAME);
    collection = db.collection(COLLECTION_NAME);
    

    
  } catch (error) {
    console.error('Error connecting to MongoDB:', error);
    process.exit(1);
  }
}

// Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Get all worksheets
app.get('/worksheets', async (req, res) => {
  try {
    const { page = 1, limit = 50, search } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    let query = {};
    
    // Add search functionality
    if (search) {
      query = {
        $or: [
          { chatInput: { $regex: search, $options: 'i' } },
          { text: { $regex: search, $options: 'i' } }
        ]
      };
    }
    
    const worksheets = await collection
      .find(query)
      .sort({ combined_at: -1 }) // Sort by newest first
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await collection.countDocuments(query);
    
    res.json({
      worksheets,
      pagination: {
        current_page: parseInt(page),
        per_page: parseInt(limit),
        total_pages: Math.ceil(total / parseInt(limit)),
        total_items: total
      }
    });
    
  } catch (error) {
    console.error('Error fetching worksheets:', error);
    res.status(500).json({ 
      error: 'Failed to fetch worksheets', 
      details: error.message 
    });
  }
});

// Get single worksheet by ID
app.get('/worksheets/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongodb');
    const worksheetId = req.params.id;
    
    if (!ObjectId.isValid(worksheetId)) {
      return res.status(400).json({ error: 'Invalid worksheet ID' });
    }
    
    const worksheet = await collection.findOne({ 
      _id: new ObjectId(worksheetId) 
    });
    
    if (!worksheet) {
      return res.status(404).json({ error: 'Worksheet not found' });
    }
    
    res.json(worksheet);
    
  } catch (error) {
    console.error('Error fetching worksheet:', error);
    res.status(500).json({ 
      error: 'Failed to fetch worksheet', 
      details: error.message 
    });
  }
});

// Get worksheets by subject/topic
app.get('/worksheets/subject/:subject', async (req, res) => {
  try {
    const subject = req.params.subject;
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const worksheets = await collection
      .find({ 
        chatInput: { $regex: subject, $options: 'i' } 
      })
      .sort({ combined_at: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    res.json(worksheets);
    
  } catch (error) {
    console.error('Error fetching worksheets by subject:', error);
    res.status(500).json({ 
      error: 'Failed to fetch worksheets by subject', 
      details: error.message 
    });
  }
});

// Get recent worksheets
app.get('/worksheets/recent/:days', async (req, res) => {
  try {
    const days = parseInt(req.params.days) || 7;
    const dateThreshold = new Date();
    dateThreshold.setDate(dateThreshold.getDate() - days);
    
    const worksheets = await collection
      .find({
        combined_at: { 
          $gte: dateThreshold.toISOString() 
        }
      })
      .sort({ combined_at: -1 })
      .limit(50)
      .toArray();
    
    res.json(worksheets);
    
  } catch (error) {
    console.error('Error fetching recent worksheets:', error);
    res.status(500).json({ 
      error: 'Failed to fetch recent worksheets', 
      details: error.message 
    });
  }
});

// Get unique subjects/topics
app.get('/subjects', async (req, res) => {
  try {
    const subjects = await collection.distinct('chatInput');
    const filteredSubjects = subjects.filter(subject => 
      subject && subject.trim() !== ''
    );
    
    res.json(filteredSubjects.sort());
    
  } catch (error) {
    console.error('Error fetching subjects:', error);
    res.status(500).json({ 
      error: 'Failed to fetch subjects', 
      details: error.message 
    });
  }
});

// Delete worksheet (optional - for cleanup)
app.delete('/worksheets/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongodb');
    const worksheetId = req.params.id;
    
    if (!ObjectId.isValid(worksheetId)) {
      return res.status(400).json({ error: 'Invalid worksheet ID' });
    }
    
    const result = await collection.deleteOne({ 
      _id: new ObjectId(worksheetId) 
    });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'Worksheet not found' });
    }
    
    res.json({ message: 'Worksheet deleted successfully' });
    
  } catch (error) {
    console.error('Error deleting worksheet:', error);
    res.status(500).json({ 
      error: 'Failed to delete worksheet', 
      details: error.message 
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error', 
    details: err.message 
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
async function startServer() {
  await connectToMongoDB();
  
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Worksheets API: http://localhost:${PORT}/worksheets`);
  });
}

startServer().catch(console.error);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Shutting down server...');
  if (db) {
    await db.client.close();
  }
  process.exit(0);
});
