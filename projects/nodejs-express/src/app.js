const express = require('express');
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

// MongoDB connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://user:password@db:27017/ordersdb?authSource=admin';

mongoose.connect(MONGO_URI)
  .then(() => console.log('MongoDB connected'))
  .catch(err => { console.error('MongoDB error:', err); process.exit(1); });

// Order schema
const orderSchema = new mongoose.Schema({
  customerId: { type: String, required: true },
  items: [{
    productId: String,
    name: String,
    quantity: { type: Number, min: 1 },
    price: Number
  }],
  status: {
    type: String,
    enum: ['pending', 'processing', 'shipped', 'delivered', 'cancelled'],
    default: 'pending'
  },
  totalAmount: Number,
  shippingAddress: {
    street: String,
    city: String,
    country: String,
    zip: String
  }
}, { timestamps: true });

const Order = mongoose.model('Order', orderSchema);

// Routes
app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'order-api' }));

app.get('/orders', async (req, res) => {
  try {
    const { customerId, status, page = 1, limit = 20 } = req.query;
    const filter = {};
    if (customerId) filter.customerId = customerId;
    if (status) filter.status = status;
    const orders = await Order.find(filter)
      .skip((page - 1) * limit).limit(Number(limit)).sort({ createdAt: -1 });
    const total = await Order.countDocuments(filter);
    res.json({ orders, total, page: Number(page), pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/orders', async (req, res) => {
  try {
    const { items, ...rest } = req.body;
    const totalAmount = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
    const order = new Order({ ...rest, items, totalAmount });
    await order.save();
    res.status(201).json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get('/orders/:id', async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json(order);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/orders/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findByIdAndUpdate(
      req.params.id, { status }, { new: true, runValidators: true }
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/orders/:id', async (req, res) => {
  try {
    const order = await Order.findByIdAndDelete(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Order API running on :${PORT}`));

module.exports = app;
