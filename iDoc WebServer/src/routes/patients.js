const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Patient = require('../models/Patient');
const { auth } = require('../middleware/auth');

// Get all patients (with pagination and search)
router.get('/', auth, async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const search = req.query.search || '';
        const skip = (page - 1) * limit;

        const query = {
            $or: [
                { firstName: { $regex: search, $options: 'i' } },
                { lastName: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } }
            ],
            'assignedDoctors.doctor': req.user._id
        };

        const patients = await Patient.find(query)
            .sort({ lastName: 1, firstName: 1 })
            .skip(skip)
            .limit(limit)
            .populate('assignedDoctors.doctor', 'firstName lastName specialty');

        const total = await Patient.countDocuments(query);

        res.json({
            patients,
            total,
            pages: Math.ceil(total / limit),
            currentPage: page
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Get single patient
router.get('/:id', auth, async (req, res) => {
    try {
        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        }).populate('assignedDoctors.doctor', 'firstName lastName specialty');

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Create new patient
router.post('/', auth, [
    body('firstName').trim().notEmpty().withMessage('First name is required'),
    body('lastName').trim().notEmpty().withMessage('Last name is required'),
    body('dateOfBirth').isISO8601().withMessage('Valid date of birth is required'),
    body('gender').isIn(['male', 'female', 'other', 'prefer not to say']).withMessage('Valid gender is required'),
    body('email').optional().isEmail().withMessage('Valid email is required'),
    body('phoneNumber').optional().trim(),
    body('address').optional().isObject(),
    body('emergencyContact').optional().isObject(),
    body('insurance').optional().isObject()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = new Patient({
            ...req.body,
            assignedDoctors: [{
                doctor: req.user._id,
                role: 'primary'
            }]
        });

        await patient.save();
        res.status(201).json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Update patient
router.put('/:id', auth, [
    body('firstName').optional().trim().notEmpty(),
    body('lastName').optional().trim().notEmpty(),
    body('dateOfBirth').optional().isISO8601(),
    body('gender').optional().isIn(['male', 'female', 'other', 'prefer not to say']),
    body('email').optional().isEmail(),
    body('phoneNumber').optional().trim(),
    body('address').optional().isObject(),
    body('emergencyContact').optional().isObject(),
    body('insurance').optional().isObject()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        Object.keys(req.body).forEach(key => {
            if (req.body[key] !== undefined) {
                patient[key] = req.body[key];
            }
        });

        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add medical history
router.post('/:id/medical-history', auth, [
    body('condition').trim().notEmpty().withMessage('Condition is required'),
    body('diagnosisDate').isISO8601().withMessage('Valid diagnosis date is required'),
    body('status').isIn(['active', 'resolved', 'monitoring']).withMessage('Valid status is required'),
    body('notes').optional().trim()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        patient.medicalHistory.push(req.body);
        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add allergy
router.post('/:id/allergies', auth, [
    body('allergen').trim().notEmpty().withMessage('Allergen is required'),
    body('severity').isIn(['mild', 'moderate', 'severe', 'life-threatening']).withMessage('Valid severity is required'),
    body('notes').optional().trim()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        patient.allergies.push(req.body);
        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add medication
router.post('/:id/medications', auth, [
    body('name').trim().notEmpty().withMessage('Medication name is required'),
    body('dosage').trim().notEmpty().withMessage('Dosage is required'),
    body('frequency').trim().notEmpty().withMessage('Frequency is required'),
    body('startDate').isISO8601().withMessage('Valid start date is required'),
    body('endDate').optional().isISO8601(),
    body('notes').optional().trim()
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        patient.medications.push({
            ...req.body,
            prescribedBy: req.user._id
        });
        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Add note
router.post('/:id/notes', auth, [
    body('content').trim().notEmpty().withMessage('Note content is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        patient.notes.push({
            content: req.body.content,
            author: req.user._id
        });
        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

// Assign doctor to patient
router.post('/:id/assign-doctor', auth, [
    body('doctorId').isMongoId().withMessage('Valid doctor ID is required'),
    body('role').isIn(['primary', 'specialist', 'consultant']).withMessage('Valid role is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const patient = await Patient.findOne({
            _id: req.params.id,
            'assignedDoctors.doctor': req.user._id
        });

        if (!patient) {
            return res.status(404).json({ message: 'Patient not found' });
        }

        // Check if doctor is already assigned
        const isAlreadyAssigned = patient.assignedDoctors.some(
            assignment => assignment.doctor.toString() === req.body.doctorId
        );

        if (isAlreadyAssigned) {
            return res.status(400).json({ message: 'Doctor is already assigned to this patient' });
        }

        patient.assignedDoctors.push({
            doctor: req.body.doctorId,
            role: req.body.role
        });

        await patient.save();
        res.json(patient);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router; 