const mongoose = require('mongoose');

const patientSchema = new mongoose.Schema({
    firstName: {
        type: String,
        required: true,
        trim: true
    },
    lastName: {
        type: String,
        required: true,
        trim: true
    },
    dateOfBirth: {
        type: Date,
        required: true
    },
    gender: {
        type: String,
        enum: ['male', 'female', 'other', 'prefer not to say'],
        required: true
    },
    email: {
        type: String,
        trim: true,
        lowercase: true
    },
    phoneNumber: {
        type: String,
        trim: true
    },
    address: {
        street: String,
        city: String,
        state: String,
        zipCode: String,
        country: String
    },
    emergencyContact: {
        name: String,
        relationship: String,
        phoneNumber: String
    },
    insurance: {
        provider: String,
        policyNumber: String,
        groupNumber: String
    },
    medicalHistory: [{
        condition: String,
        diagnosisDate: Date,
        status: {
            type: String,
            enum: ['active', 'resolved', 'monitoring'],
            default: 'active'
        },
        notes: String
    }],
    allergies: [{
        allergen: String,
        severity: {
            type: String,
            enum: ['mild', 'moderate', 'severe', 'life-threatening'],
            default: 'mild'
        },
        notes: String
    }],
    medications: [{
        name: String,
        dosage: String,
        frequency: String,
        startDate: Date,
        endDate: Date,
        prescribedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        notes: String
    }],
    assignedDoctors: [{
        doctor: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        role: {
            type: String,
            enum: ['primary', 'specialist', 'consultant'],
            default: 'primary'
        },
        assignedDate: {
            type: Date,
            default: Date.now
        }
    }],
    documents: [{
        title: String,
        type: String,
        url: String,
        uploadDate: {
            type: Date,
            default: Date.now
        },
        uploadedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }],
    notes: [{
        content: String,
        date: {
            type: Date,
            default: Date.now
        },
        author: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }],
    status: {
        type: String,
        enum: ['active', 'inactive', 'deceased'],
        default: 'active'
    }
}, {
    timestamps: true
});

// Indexes for better query performance
patientSchema.index({ firstName: 1, lastName: 1 });
patientSchema.index({ dateOfBirth: 1 });
patientSchema.index({ 'assignedDoctors.doctor': 1 });

const Patient = mongoose.model('Patient', patientSchema);

module.exports = Patient; 