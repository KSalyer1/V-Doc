const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Order = require('../models/Order');
const { auth } = require('../middleware/auth');

// Get all orders for a patient
router.get('/patient/:patientId', auth, async (req, res) => {
    try {
        const {
            type,
            status,
            startDate,
            endDate,
            page = 1,
            limit = 10
        } = req.query;

        const query = {
            patient: req.params.patientId,
            doctor: req.user._id
        };

        if (type) {
            query.type = type;
        }

        if (status) {
            query.status = status;
        }

        if (startDate && endDate) {
            query.createdAt = {
                $gte: new Date(startDate),
                $lte: new Date(endDate)
            };
        }

        const skip = (page - 1) * limit;

        const orders = await Order.find(query)
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .populate('appointment', 'date type');

        const total = await Order.countDocuments(query);

        res.json({
            orders,
            total,
            pages: Math.ceil(total / limit),
            currentPage: page
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single order
router.get('/:id', auth, async (req, res) => {
    try {
        const order = await Order.findOne({
            _id: req.params.id,
            doctor: req.user._id
        }).populate('appointment', 'date type');

        if (!order) {
            return res.status(404).json({ message: 'Order not found' });
        }

        res.json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create new order
router.post('/', auth, [
    body('patient').isMongoId().withMessage('Valid patient ID is required'),
    body('type').isIn(['medication', 'lab', 'imaging', 'procedure', 'referral', 'other']).withMessage('Valid order type is required'),
    body('priority').optional().isIn(['routine', 'urgent', 'stat']),
    body('appointment').optional().isMongoId(),
    body('details').isObject().withMessage('Order details are required'),
    body('notes').optional().trim()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const order = new Order({
            ...req.body,
            doctor: req.user._id
        });

        // Add initial history entry
        order.history.push({
            status: order.status,
            updatedBy: req.user._id,
            notes: 'Order created'
        });

        await order.save();
        res.status(201).json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update order
router.put('/:id', auth, [
    body('priority').optional().isIn(['routine', 'urgent', 'stat']),
    body('details').optional().isObject(),
    body('notes').optional().trim(),
    body('status').optional().isIn(['draft', 'pending', 'ordered', 'completed', 'cancelled', 'rejected'])
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const order = await Order.findOne({
            _id: req.params.id,
            doctor: req.user._id,
            status: { $ne: 'completed' }
        });

        if (!order) {
            return res.status(404).json({ message: 'Order not found or already completed' });
        }

        Object.keys(req.body).forEach(key => {
            if (req.body[key] !== undefined) {
                order[key] = req.body[key];
            }
        });

        await order.save();
        res.json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add attachment to order
router.post('/:id/attachments', auth, [
    body('title').trim().notEmpty().withMessage('Title is required'),
    body('type').trim().notEmpty().withMessage('Type is required'),
    body('url').trim().notEmpty().withMessage('URL is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const order = await Order.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!order) {
            return res.status(404).json({ message: 'Order not found' });
        }

        order.attachments.push({
            ...req.body,
            uploadedBy: req.user._id
        });

        await order.save();
        res.json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add alert to order
router.post('/:id/alerts', auth, [
    body('type').isIn(['drug-interaction', 'allergy', 'contraindication', 'lab-value', 'other']).withMessage('Valid alert type is required'),
    body('severity').isIn(['low', 'medium', 'high']).withMessage('Valid severity is required'),
    body('message').trim().notEmpty().withMessage('Alert message is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const order = await Order.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!order) {
            return res.status(404).json({ message: 'Order not found' });
        }

        order.addAlert(req.body.type, req.body.severity, req.body.message);
        await order.save();
        res.json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Acknowledge alert
router.put('/:id/alerts/:alertId/acknowledge', auth, async (req, res) => {
    try {
        const order = await Order.findOne({
            _id: req.params.id,
            doctor: req.user._id
        });

        if (!order) {
            return res.status(404).json({ message: 'Order not found' });
        }

        order.acknowledgeAlert(req.params.alertId, req.user._id);
        await order.save();
        res.json(order);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get pending orders
router.get('/pending', auth, async (req, res) => {
    try {
        const orders = await Order.find({
            doctor: req.user._id,
            status: 'pending'
        })
        .populate('patient', 'firstName lastName')
        .populate('appointment', 'date type')
        .sort({ createdAt: -1 });

        res.json(orders);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get orders with unacknowledged alerts
router.get('/alerts/unacknowledged', auth, async (req, res) => {
    try {
        const orders = await Order.find({
            doctor: req.user._id,
            'alerts.acknowledged': false
        })
        .populate('patient', 'firstName lastName')
        .populate('appointment', 'date type')
        .sort({ createdAt: -1 });

        res.json(orders);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get medication orders with drug interactions
router.get('/medications/interactions', auth, async (req, res) => {
    try {
        const orders = await Order.find({
            doctor: req.user._id,
            type: 'medication',
            'details.medication.drugInteractions': { $exists: true, $ne: [] }
        })
        .populate('patient', 'firstName lastName')
        .populate('appointment', 'date type')
        .sort({ createdAt: -1 });

        res.json(orders);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router; 