/**
 * Forms Component Module
 * Handles form validation, submission, and user interactions
 */

class FormManager {
    constructor() {
        this.forms = new Map();
        this.validators = new Map();
        this.isInitialized = false;
        
        // Default validation rules
        this.defaultRules = {
            required: (value) => value && value.trim() !== '',
            email: (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
            number: (value) => !isNaN(parseFloat(value)) && isFinite(value),
            minLength: (value, min) => value && value.length >= min,
            maxLength: (value, max) => value && value.length <= max,
            min: (value, min) => parseFloat(value) >= min,
            max: (value, max) => parseFloat(value) <= max,
            pattern: (value, pattern) => new RegExp(pattern).test(value)
        };
        
        console.log('📝 Form Manager initialized');
    }
    
    /**
     * Initialize form management
     */
    initialize() {
        try {
            this.findAndRegisterForms();
            this.setupGlobalEventListeners();
            
            this.isInitialized = true;
            console.log('✅ Form management initialized');
            return true;
        } catch (error) {
            console.error('❌ Form initialization failed:', error);
            return false;
        }
    }
    
    /**
     * Find and register all forms
     */
    findAndRegisterForms() {
        const forms = document.querySelectorAll('form');
        forms.forEach(form => {
            this.registerForm(form);
        });
    }
    
    /**
     * Register a form for management
     */
    registerForm(formElement, options = {}) {
        if (!formElement.id) {
            formElement.id = `form-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        }
        
        const formConfig = {
            element: formElement,
            validators: new Map(),
            options: {
                validateOnBlur: true,
                validateOnInput: false,
                showErrorsInline: true,
                preventSubmitOnError: true,
                ...options
            },
            isValid: true,
            errors: new Map()
        };
        
        this.forms.set(formElement.id, formConfig);
        this.setupFormEventListeners(formElement, formConfig);
        
        console.log('📝 Form registered:', formElement.id);
        return formElement.id;
    }
    
    /**
     * Setup event listeners for a form
     */
    setupFormEventListeners(formElement, formConfig) {
        // Form submission
        formElement.addEventListener('submit', (e) => {
            this.handleFormSubmit(e, formConfig);
        });
        
        // Field validation on blur/input
        const fields = formElement.querySelectorAll('input, textarea, select');
        fields.forEach(field => {
            if (formConfig.options.validateOnBlur) {
                field.addEventListener('blur', () => {
                    this.validateField(field, formConfig);
                });
            }
            
            if (formConfig.options.validateOnInput) {
                field.addEventListener('input', () => {
                    this.clearFieldError(field);
                    
                    // Debounced validation
                    clearTimeout(field.validationTimeout);
                    field.validationTimeout = setTimeout(() => {
                        this.validateField(field, formConfig);
                    }, 300);
                });
            }
            
            // Clear errors on focus
            field.addEventListener('focus', () => {
                this.clearFieldError(field);
            });
        });
    }
    
    /**
     * Setup global event listeners
     */
    setupGlobalEventListeners() {
        // File input styling
        document.addEventListener('change', (e) => {
            if (e.target.type === 'file') {
                this.handleFileInputChange(e.target);
            }
        });
        
        // Auto-resize textareas
        document.addEventListener('input', (e) => {
            if (e.target.tagName === 'TEXTAREA' && e.target.classList.contains('auto-resize')) {
                this.autoResizeTextarea(e.target);
            }
        });
    }
    
    /**
     * Add validation rule to a field
     */
    addValidation(formId, fieldName, rule, options = {}) {
        const formConfig = this.forms.get(formId);
        if (!formConfig) {
            console.error('❌ Form not found:', formId);
            return false;
        }
        
        if (!formConfig.validators.has(fieldName)) {
            formConfig.validators.set(fieldName, []);
        }
        
        formConfig.validators.get(fieldName).push({
            rule,
            options,
            message: options.message || this.getDefaultErrorMessage(rule, options)
        });
        
        console.log(`📝 Added validation rule '${rule}' to field '${fieldName}' in form '${formId}'`);
        return true;
    }
    
    /**
     * Validate a specific field
     */
    validateField(field, formConfig) {
        const fieldName = field.name || field.id;
        if (!fieldName) return true;
        
        const validators = formConfig.validators.get(fieldName) || [];
        const value = this.getFieldValue(field);
        
        // Clear previous errors
        formConfig.errors.delete(fieldName);
        this.clearFieldError(field);
        
        // Run validators
        for (const validator of validators) {
            if (!this.runValidator(value, validator)) {
                formConfig.errors.set(fieldName, validator.message);
                
                if (formConfig.options.showErrorsInline) {
                    this.showFieldError(field, validator.message);
                }
                
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Validate entire form
     */
    validateForm(formId) {
        const formConfig = this.forms.get(formId);
        if (!formConfig) {
            console.error('❌ Form not found:', formId);
            return false;
        }
        
        const fields = formConfig.element.querySelectorAll('input, textarea, select');
        let isValid = true;
        
        formConfig.errors.clear();
        
        fields.forEach(field => {
            if (!this.validateField(field, formConfig)) {
                isValid = false;
            }
        });
        
        formConfig.isValid = isValid;
        
        // Update form visual state
        if (isValid) {
            formConfig.element.classList.remove('form-invalid');
            formConfig.element.classList.add('form-valid');
        } else {
            formConfig.element.classList.add('form-invalid');
            formConfig.element.classList.remove('form-valid');
        }
        
        console.log(`📝 Form validation ${isValid ? 'passed' : 'failed'}:`, formId);
        return isValid;
    }
    
    /**
     * Handle form submission
     */
    handleFormSubmit(event, formConfig) {
        const isValid = this.validateForm(formConfig.element.id);
        
        if (!isValid && formConfig.options.preventSubmitOnError) {
            event.preventDefault();
            
            // Focus first error field
            const firstErrorField = formConfig.element.querySelector('.field-error');
            if (firstErrorField) {
                const field = firstErrorField.closest('.form-group')?.querySelector('input, textarea, select');
                if (field) {
                    field.focus();
                }
            }
            
            console.log('❌ Form submission prevented due to validation errors');
            return false;
        }
        
        // Trigger custom event
        formConfig.element.dispatchEvent(new CustomEvent('formValidated', {
            detail: { isValid, errors: Object.fromEntries(formConfig.errors) }
        }));
        
        return isValid;
    }
    
    /**
     * Run a single validator
     */
    runValidator(value, validator) {
        const { rule, options } = validator;
        
        // Skip validation for empty optional fields
        if (!value && rule !== 'required') {
            return true;
        }
        
        if (typeof rule === 'string' && this.defaultRules[rule]) {
            return this.defaultRules[rule](value, options.param, options);
        } else if (typeof rule === 'function') {
            return rule(value, options);
        }
        
        console.warn('⚠️ Unknown validation rule:', rule);
        return true;
    }
    
    /**
     * Get field value
     */
    getFieldValue(field) {
        switch (field.type) {
            case 'checkbox':
                return field.checked;
            case 'radio':
                const radioGroup = document.querySelectorAll(`input[name="${field.name}"]`);
                for (const radio of radioGroup) {
                    if (radio.checked) {
                        return radio.value;
                    }
                }
                return null;
            case 'file':
                return field.files.length > 0 ? field.files : null;
            default:
                return field.value;
        }
    }
    
    /**
     * Show field error
     */
    showFieldError(field, message) {
        this.clearFieldError(field);
        
        const errorElement = document.createElement('div');
        errorElement.className = 'field-error';
        errorElement.textContent = message;
        
        // Add error styling to field
        field.classList.add('field-invalid');
        
        // Insert error message
        const formGroup = field.closest('.form-group') || field.parentNode;
        formGroup.appendChild(errorElement);
    }
    
    /**
     * Clear field error
     */
    clearFieldError(field) {
        // Remove error styling
        field.classList.remove('field-invalid');
        
        // Remove error message
        const formGroup = field.closest('.form-group') || field.parentNode;
        const errorElement = formGroup.querySelector('.field-error');
        if (errorElement) {
            errorElement.remove();
        }
    }
    
    /**
     * Get form data as object
     */
    getFormData(formId) {
        const formConfig = this.forms.get(formId);
        if (!formConfig) {
            console.error('❌ Form not found:', formId);
            return null;
        }
        
        const formData = new FormData(formConfig.element);
        const data = {};
        
        // Convert FormData to object
        for (const [key, value] of formData.entries()) {
            if (data[key]) {
                // Handle multiple values (like checkboxes)
                if (Array.isArray(data[key])) {
                    data[key].push(value);
                } else {
                    data[key] = [data[key], value];
                }
            } else {
                data[key] = value;
            }
        }
        
        // Handle checkboxes that aren't checked
        const checkboxes = formConfig.element.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            if (!checkbox.checked && !data.hasOwnProperty(checkbox.name)) {
                data[checkbox.name] = false;
            }
        });
        
        return data;
    }
    
    /**
     * Set form data from object
     */
    setFormData(formId, data) {
        const formConfig = this.forms.get(formId);
        if (!formConfig) {
            console.error('❌ Form not found:', formId);
            return false;
        }
        
        Object.entries(data).forEach(([key, value]) => {
            const field = formConfig.element.querySelector(`[name="${key}"]`);
            if (field) {
                switch (field.type) {
                    case 'checkbox':
                        field.checked = Boolean(value);
                        break;
                    case 'radio':
                        const radioOption = formConfig.element.querySelector(`[name="${key}"][value="${value}"]`);
                        if (radioOption) {
                            radioOption.checked = true;
                        }
                        break;
                    default:
                        field.value = value;
                }
            }
        });
        
        console.log('📝 Form data set for:', formId);
        return true;
    }
    
    /**
     * Reset form
     */
    resetForm(formId) {
        const formConfig = this.forms.get(formId);
        if (!formConfig) {
            console.error('❌ Form not found:', formId);
            return false;
        }
        
        formConfig.element.reset();
        formConfig.errors.clear();
        formConfig.isValid = true;
        
        // Clear all error states
        const fields = formConfig.element.querySelectorAll('input, textarea, select');
        fields.forEach(field => {
            this.clearFieldError(field);
        });
        
        formConfig.element.classList.remove('form-invalid', 'form-valid');
        
        console.log('📝 Form reset:', formId);
        return true;
    }
    
    /**
     * Handle file input change
     */
    handleFileInputChange(fileInput) {
        const files = Array.from(fileInput.files);
        
        // Update label text if present
        const label = document.querySelector(`label[for="${fileInput.id}"]`);
        if (label) {
            if (files.length === 0) {
                label.textContent = label.dataset.originalText || 'Choose files';
            } else if (files.length === 1) {
                label.textContent = files[0].name;
            } else {
                label.textContent = `${files.length} files selected`;
            }
        }
        
        // Create file preview if container exists
        const previewContainer = document.getElementById(`${fileInput.id}-preview`);
        if (previewContainer) {
            this.createFilePreview(files, previewContainer);
        }
    }
    
    /**
     * Create file preview
     */
    createFilePreview(files, container) {
        container.innerHTML = '';
        
        files.forEach((file, index) => {
            const preview = document.createElement('div');
            preview.className = 'file-preview-item';
            
            if (file.type.startsWith('image/')) {
                const img = document.createElement('img');
                img.src = URL.createObjectURL(file);
                img.className = 'preview-image';
                preview.appendChild(img);
            } else {
                const icon = document.createElement('div');
                icon.className = 'file-icon';
                icon.textContent = this.getFileIcon(file.type);
                preview.appendChild(icon);
            }
            
            const info = document.createElement('div');
            info.className = 'file-info';
            info.innerHTML = `
                <div class="file-name">${this.escapeHtml(file.name)}</div>
                <div class="file-size">${this.formatFileSize(file.size)}</div>
            `;
            preview.appendChild(info);
            
            container.appendChild(preview);
        });
    }
    
    /**
     * Auto-resize textarea
     */
    autoResizeTextarea(textarea) {
        textarea.style.height = 'auto';
        textarea.style.height = textarea.scrollHeight + 'px';
    }
    
    /**
     * Get default error message
     */
    getDefaultErrorMessage(rule, options) {
        const messages = {
            required: 'This field is required',
            email: 'Please enter a valid email address',
            number: 'Please enter a valid number',
            minLength: `Minimum length is ${options.param} characters`,
            maxLength: `Maximum length is ${options.param} characters`,
            min: `Minimum value is ${options.param}`,
            max: `Maximum value is ${options.param}`,
            pattern: 'Please match the required format'
        };
        
        return messages[rule] || 'Invalid value';
    }
    
    /**
     * Get file icon
     */
    getFileIcon(mimeType) {
        if (mimeType.startsWith('image/')) return '🖼️';
        if (mimeType.includes('pdf')) return '📄';
        if (mimeType.includes('word')) return '📝';
        if (mimeType.includes('excel')) return '📊';
        if (mimeType.includes('powerpoint')) return '📊';
        return '📎';
    }
    
    /**
     * Format file size
     */
    formatFileSize(bytes) {
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0 Byte';
        const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
        return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    /**
     * Escape HTML
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    /**
     * Get form errors
     */
    getFormErrors(formId) {
        const formConfig = this.forms.get(formId);
        return formConfig ? Object.fromEntries(formConfig.errors) : {};
    }
    
    /**
     * Check if form is valid
     */
    isFormValid(formId) {
        const formConfig = this.forms.get(formId);
        return formConfig ? formConfig.isValid : false;
    }
    
    /**
     * Cleanup
     */
    cleanup() {
        this.forms.clear();
        this.validators.clear();
        this.isInitialized = false;
        
        console.log('🧹 Form management cleaned up');
    }
}

// Global form manager instance
let globalFormManager = null;

/**
 * Initialize form management (backward compatibility)
 */
function initializeForms() {
    if (!globalFormManager) {
        globalFormManager = new FormManager();
    }
    
    return globalFormManager.initialize();
}

/**
 * Register form (backward compatibility)
 */
function registerForm(formElement, options) {
    if (globalFormManager) {
        return globalFormManager.registerForm(formElement, options);
    }
    return null;
}

/**
 * Validate form (backward compatibility)
 */
function validateForm(formId) {
    if (globalFormManager) {
        return globalFormManager.validateForm(formId);
    }
    return false;
}

/**
 * Get form data (backward compatibility)
 */
function getFormData(formId) {
    if (globalFormManager) {
        return globalFormManager.getFormData(formId);
    }
    return null;
}

// Export for ES6 modules
export {
    FormManager,
    initializeForms,
    registerForm,
    validateForm,
    getFormData
};

// Export to window for backward compatibility
window.FormManager = FormManager;
window.initializeForms = initializeForms;
window.registerForm = registerForm;
window.validateForm = validateForm;
window.getFormData = getFormData;
window.globalFormManager = () => globalFormManager;