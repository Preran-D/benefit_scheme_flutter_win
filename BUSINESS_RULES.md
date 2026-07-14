# SGSH Benefit Scheme - Business Rules & Constraints

## 1. Customer Screen Constraints
- **Unique Name**: You cannot save a customer with a name that already exists in the system.
- **Deletion Block**: The "Delete" button for a customer should ideally be disabled (or show a warning) if they have any payments in any of their schemes. The DB will block deletion if any payment history exists.

## 2. Scheme Creation & Editing Constraints
- **Minimum Amount**: `monthly_amount` must be at least ₹500.
- **Amount Increments**: `monthly_amount` must be a multiple of ₹100 (e.g., ₹700 is valid, ₹750 is not).
- **Creation Date**: The scheme "Start Date" (`created_at`) cannot be a future date.
- **Edit Lock (Amount)**: If a scheme already has payments, the Monthly Amount field should be disabled in the UI. The DB will reject any change to this amount unless payments are deleted first.
- **Edit Lock (Date)**: If a scheme has payments, the Start Date cannot be changed to a date later than the first payment.
  - *UI Tip*: Set the `maxDate` of your DatePicker to the date of the first payment.

## 3. Scheme Closing Constraints
- **No "Empty" Closing**: You cannot change a scheme's status to "Closed" or "Completed" if the Total Paid is ₹0.
- **Closing Date Logic**:
  - Cannot be in the future.
  - Cannot be before the Last Payment Date.
  - *UI Tip*: If the last payment was on Dec 1st, the DatePicker for closing the scheme should disable all dates before Dec 1st.

## 4. Payment Entry Constraints 
- **Strict Amount**: The payment amount must exactly match the scheme's `monthly_amount`.
  - *UI Tip*: You should ideally pre-fill this field and make it read-only for the user.
- **No Zero/Null**: Payments of ₹0 or empty values are strictly forbidden.
- **No Future Payments**: The "Payment Date" cannot be later than today.
- **Payment Limit**: A scheme only accepts up to 12 months of payments (Total Paid cannot exceed Monthly Amount × 12).
  - *UI Tip*: Disable the "Add Payment" button once the 12th payment is reached.

## 5. Deletion Constraints
- **Scheme Deletion**: A scheme cannot be deleted if it has recorded payments.
  - *UI Logic*: Show a message: "Delete all payments for this scheme before deleting the scheme itself."
