const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
    patient: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Patient',
        required: true
    },
    doctor: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    appointment: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Appointment'
    },
    type: {
        type: String,
        enum: ['medication', 'lab', 'imaging', 'procedure', 'referral', 'other'],
        required: true
    },
    status: {
        type: String,
        enum: ['draft', 'pending', 'ordered', 'completed', 'cancelled', 'rejected'],
        default: 'draft'
    },
    priority: {
        type: String,
        enum: ['routine', 'urgent', 'stat'],
        default: 'routine'
    },
    details: {
        // Medication specific fields
        medication: {
            name: String,
            dosage: String,
            frequency: String,
            duration: String,
            instructions: String,
            refills: Number,
            pharmacy: String,
            drugInteractions: [{
                medication: String,
                severity: {
                    type: String,
                    enum: ['mild', 'moderate', 'severe'],
                    default: 'mild'
                },
                description: String
            }]
        },
        // Lab specific fields
        lab: {
            testName: String,
            specimenType: String,
            collectionInstructions: String,
            fastingRequired: Boolean,
            specialInstructions: String
        },
        // Imaging specific fields
        imaging: {
            studyType: String,
            bodyPart: String,
            contrast: Boolean,
            specialInstructions: String
        },
        // Procedure specific fields
        procedure: {
            name: String,
            location: String,
            instructions: String,
            anesthesia: String,
            specialInstructions: String
        },
        // Referral specific fields
        referral: {
            specialist: {
                type: mongoose.Schema.Types.ObjectId,
                ref: 'User'
            },
            reason: String,
            urgency: String,
            notes: String
        }
    },
    notes: String,
    attachments: [{
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
    history: [{
        status: {
            type: String,
            enum: ['draft', 'pending', 'ordered', 'completed', 'cancelled', 'rejected']
        },
        date: {
            type: Date,
            default: Date.now
        },
        updatedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        notes: String
    }],
    alerts: [{
        type: {
            type: String,
            enum: ['drug-interaction', 'allergy', 'contraindication', 'lab-value', 'other'],
            required: true
        },
        severity: {
            type: String,
            enum: ['low', 'medium', 'high'],
            required: true
        },
        message: String,
        acknowledged: {
            type: Boolean,
            default: false
        },
        acknowledgedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        },
        acknowledgedAt: Date
    }],
    signature: {
        date: Date,
        doctor: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User'
        }
    }
}, {
    timestamps: true
});

// Indexes for better query performance
orderSchema.index({ patient: 1 });
orderSchema.index({ doctor: 1 });
orderSchema.index({ appointment: 1 });
orderSchema.index({ type: 1 });
orderSchema.index({ status: 1 });
orderSchema.index({ createdAt: -1 });

// Pre-save middleware to handle status changes and history
orderSchema.pre('save', function(next) {
    if (this.isModified('status')) {
        this.history.push({
            status: this.status,
            updatedBy: this.doctor,
            notes: `Status changed to ${this.status}`
        });

        if (this.status === 'ordered') {
            this.signature = {
                date: new Date(),
                doctor: this.doctor
            };
        }
    }
    next();
});

// Method to add alert
orderSchema.methods.addAlert = function(type, severity, message) {
    this.alerts.push({
        type,
        severity,
        message
    });
};

// Method to acknowledge alert
orderSchema.methods.acknowledgeAlert = function(alertId, doctorId) {
    const alert = this.alerts.id(alertId);
    if (alert) {
        alert.acknowledged = true;
        alert.acknowledgedBy = doctorId;
        alert.acknowledgedAt = new Date();
    }
};

const Order = mongoose.model('Order', orderSchema);

module.exports = Order; 