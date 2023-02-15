import { t } from '@18f/identity-i18n';
import { trackError } from '@18f/identity-analytics';
import { request } from '@18f/identity-request';

interface CheckableTransliterableFieldElement extends TransliterableFieldElement {
  fieldName: string;
  input: HTMLInputElement;
}

const VALIDATION_URL_PATH = '//in_person/validate_transliterable';
const VALIDATION_FORM_ERROR_CLASS = 'transliterable-form-error';

/**
 * This adds an asynchronous transliteration check for a form field
 * that gets run between form validation and submission.
 */
class TransliterableFieldElement extends HTMLElement {
  /**
   * Input element to be validated against transliteration API
   */
  get input(): HTMLInputElement | null {
    let inputElement: HTMLInputElement | null = null;
    const fieldId = this.getAttribute('field-id');
    if (fieldId) {
      const targetElement = this.ownerDocument.getElementById(fieldId);
      if (targetElement instanceof HTMLInputElement) {
        inputElement = targetElement;
      }
    } else {
      [inputElement = null] = this.getElementsByTagName('input');
    }
    return inputElement;
  }

  /**
   * Form associated with this field's input element
   */
  get form(): HTMLFormElement | null {
    return this.input?.form || null;
  }

  /**
   * The field name used for submitting the field value to the API
   */
  get fieldName(): string | null {
    return this.getAttribute('field-name');
  }

  /**
   * The value previously validated against the API
   */
  private previousValidatedValue: string | null;

  /**
   * Initializer for component
   */
  connectedCallback() {
    // Attach event listener for form. Will not be attached redundantly
    // because function has same identity for multiple fields.
    this.form?.addEventListener('submit', TransliterableFieldElement.handleSubmitEvent);

    // Clear prior transliteration error when input gets updated
    this.input?.addEventListener('input', () => {
      const { input } = this;
      if (input?.validity.customError) {
        input.setCustomValidity('');
      }
    });
  }

  /**
   * Check if a field is appropriately configured for validation and
   * has a value that differs from the previous validated value.
   */
  private static canFieldBeChecked(
    field: TransliterableFieldElement,
  ): field is CheckableTransliterableFieldElement {
    return !!(field.input && field.fieldName && field.previousValidatedValue !== field.input.value);
  }

  /**
   * This WeakMap tracks ongoing form submission attempts to prevent duplicate submissions.
   */
  private static lastFormSubmit = new WeakMap<HTMLFormElement, Promise<void>>();

  /**
   * Intercept form submission attempts to ensure transliterable field validation
   * occurs first.
   */
  private static async handleSubmitEvent(e: SubmitEvent): Promise<void> {
    if (!(this instanceof HTMLFormElement)) {
      // The function isn't being called correctly
      return;
    }
    const { canFieldBeChecked, handleAsyncValidation, lastFormSubmit } = TransliterableFieldElement;

    // Extract transliterable fields
    const checkTransliterable = Array.from(
      this.getElementsByTagName('lg-transliterable-field'),
    ).filter(canFieldBeChecked);

    if (checkTransliterable.length < 1) {
      // None of the transliterable fields need to be checked
      return;
    }

    // Delay form submission
    e.preventDefault();

    // Prevent redundant calls
    const form = this;
    if (!lastFormSubmit.has(form)) {
      try {
        const promise = handleAsyncValidation(form, checkTransliterable);
        lastFormSubmit.set(form, promise);
        await promise;
      } finally {
        lastFormSubmit.delete(form);
      }

      // Attempt to re-submit form. Infinite loop is prevented via the "previousValidatedValue" check.
      form.submit();
    }
  }

  /**
   * Mediate interaction between the form and API:
   * - Marshal fields to API values
   * - Set errors based on API response
   * - Prevent form interactions that could cause unintuitive behavior
   */
  private static async handleAsyncValidation(
    form: HTMLFormElement,
    checkTransliterable: CheckableTransliterableFieldElement[],
  ): Promise<void> {
    const { sendValidationRequest, setFormErrorVisibility } = TransliterableFieldElement;
    const payload = checkTransliterable.reduce(
      (agg: Record<string, string>, field) => ({
        ...agg,
        [field.fieldName]: field.input.value,
      }),
      {},
    );

    try {
      checkTransliterable.forEach((field) => {
        // Prevent user from changing the fields between validation and submission
        field.input.readOnly = true;
      });

      const result = await sendValidationRequest(payload);

      // Set custom validity on invalid fields; clear custom validity on valid fields
      checkTransliterable.forEach((field) => {
        const key = field.fieldName;
        const validationResult = result[key];
        field.previousValidatedValue = payload[key];
        field.input?.setCustomValidity(validationResult || '');
      });

      setFormErrorVisibility(form, false);
    } catch (err) {
      trackError(err);
      setFormErrorVisibility(form, true);
    } finally {
      checkTransliterable.forEach((field) => {
        // Allow user to change fields after validation has finished; useful for fixing
        // validation or other errors that prevent submission.
        field.input.readOnly = false;
      });
    }
  }

  /**
   * Update the visibility and message for the form-level error
   */
  private static setFormErrorVisibility(form: HTMLFormElement, visible: boolean) {
    const formErrorElement =
      form.getElementsByClassName(VALIDATION_FORM_ERROR_CLASS)?.[0] ||
      form.ownerDocument.getElementsByClassName(VALIDATION_FORM_ERROR_CLASS)?.[0];

    if (!formErrorElement) {
      return;
    }

    const isVisible = !formErrorElement?.classList.contains('display-none');
    if (visible && !isVisible) {
      formErrorElement.textContent = t('in_person_proofing.form.errors.transliteration');
      formErrorElement.className = Array.from(formErrorElement.classList)
        .filter((c) => c !== 'display-none')
        .join(' ');
    } else if (!visible && isVisible) {
      formErrorElement.className += ' display-none';
    }
  }

  /**
   * Wrapper for transliteration API call
   */
  private static sendValidationRequest(
    fields: Record<string, string>,
  ): Promise<Record<string, string>> {
    return request<Record<string, string>>(VALIDATION_URL_PATH, {
      method: 'POST',
      body: JSON.stringify(fields),
    });
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-transliterable-field': TransliterableFieldElement;
  }
}

if (!customElements.get('lg-transliterable-field')) {
  customElements.define('lg-transliterable-field', TransliterableFieldElement);
}
