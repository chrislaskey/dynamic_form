defmodule Demo.FormInstances do
  @moduledoc """
  Shared form instance configurations for testing DynamicForm renderers.

  This module provides reusable form instances that can be used across
  multiple test pages and examples, using SurveyJS-compatible format.
  """

  alias DynamicForm.Instance

  @doc """
  Returns a contact form instance with various question types.

  This form includes:
  - HTML elements (headings, paragraphs, dividers)
  - Text question (name)
  - Email text question with inputType
  - Dropdown question (subject)
  - Comment/textarea question (message) with length validators
  - Number input with numeric validators
  - Boolean question (subscribe)
  - Panel with grouped questions
  """
  def contact_form do
    %Instance{
      id: "contact-form",
      title: "Contact Form",
      description: "Please fill out this form to get in touch with us.",
      elements: [
        %Instance.Element{
          name: "contact-heading",
          type: "html",
          html: "<h3 class=\"text-xl font-semibold text-gray-900\">Contact Information</h3>"
        },
        %Instance.Element{
          name: "contact-intro",
          type: "html",
          html:
            "<p class=\"text-gray-600 mb-4\">We'd love to hear from you! Fill out the form below and we'll get back to you as soon as possible.</p>"
        },
        %Instance.Question{
          name: "name",
          type: "text",
          title: "Full Name",
          placeholder: "John Doe",
          description: "Enter your full name as it appears on official documents",
          isRequired: true,
          validators: [
            %Instance.Validator{type: "text", minLength: 2}
          ]
        },
        %Instance.Question{
          name: "email",
          type: "text",
          inputType: "email",
          title: "Email Address",
          placeholder: "john@example.com",
          description: "We'll never share your email with anyone else",
          isRequired: true,
          validators: [
            %Instance.Validator{type: "email"}
          ]
        },
        %Instance.Element{
          name: "contact-group",
          type: "panel",
          title: "Contact Preferences",
          elements: [
            %Instance.Question{
              name: "phone",
              type: "text",
              title: "Phone Number",
              placeholder: "(555) 123-4567",
              isRequired: false
            },
            %Instance.Question{
              name: "preferred_contact",
              type: "dropdown",
              title: "Preferred Contact Method",
              isRequired: false,
              choices: [
                {"Email", "email"},
                {"Phone", "phone"},
                {"Either", "either"}
              ]
            }
          ]
        },
        %Instance.Element{
          name: "divider-1",
          type: "html",
          html: "<hr class=\"my-6 border-gray-300\" />"
        },
        %Instance.Element{
          name: "inquiry-heading",
          type: "html",
          html: "<h3 class=\"text-xl font-semibold text-gray-900\">Your Inquiry</h3>"
        },
        %Instance.Question{
          name: "subject",
          type: "dropdown",
          title: "Subject",
          description: "Choose the topic that best matches your inquiry",
          isRequired: true,
          choices: [
            {"General Inquiry", "general"},
            {"Technical Support", "support"},
            {"Sales", "sales"},
            {"Feedback", "feedback"}
          ]
        },
        %Instance.Question{
          name: "message",
          type: "comment",
          title: "Message",
          placeholder: "Tell us how we can help you...",
          description: "Please provide as much detail as possible",
          isRequired: true,
          validators: [
            %Instance.Validator{type: "text", minLength: 10, maxLength: 1000}
          ]
        },
        %Instance.Question{
          name: "priority",
          type: "text",
          inputType: "number",
          title: "Priority (1-10)",
          placeholder: "5",
          description: "Rate the urgency of your request from 1 (low) to 10 (high)",
          isRequired: false,
          validators: [
            %Instance.Validator{type: "numeric", minValue: 1, maxValue: 10}
          ]
        },
        %Instance.Element{
          name: "divider-2",
          type: "html",
          html: "<hr class=\"my-6 border-gray-300\" />"
        },
        %Instance.Question{
          name: "subscribe",
          type: "boolean",
          title: "Subscribe to newsletter",
          description: "Receive updates about new features and announcements",
          isRequired: false
        },
        %Instance.Question{
          name: "newsletter_frequency",
          type: "dropdown",
          title: "Newsletter Frequency",
          description: "How often would you like to receive our newsletter?",
          isRequired: false,
          visibleIf: "{email} notempty",
          choices: [
            {"Daily", "daily"},
            {"Weekly", "weekly"},
            {"Monthly", "monthly"}
          ]
        }
      ],
      backend: %Instance.Backend{
        module: Demo.TestBackend,
        function: :submit,
        config: [],
        name: "Test Backend",
        description: "Logs form submissions for testing"
      },
      metadata: %{
        created_at: DateTime.utc_now()
      }
    }
  end

  @doc """
  Returns a payment form that demonstrates conditional field visibility.

  This form shows how questions can be conditionally displayed based on other question values:
  - Credit card fields only appear when payment method is "credit_card"
  - Bank account fields only appear when payment method is "bank_transfer"
  """
  def payment_form do
    %Instance{
      id: "payment-form",
      title: "Payment Form",
      description: "Complete your payment information below.",
      elements: [
        %Instance.Element{
          name: "payment-heading",
          type: "html",
          html: "<h3 class=\"text-xl font-semibold text-gray-900\">Payment Method Selection</h3>"
        },
        %Instance.Element{
          name: "payment-intro",
          type: "html",
          html:
            "<p class=\"text-gray-600 mb-4\">Select your preferred payment method and enter the required details below.</p>"
        },
        %Instance.Question{
          name: "payment_method",
          type: "dropdown",
          title: "Payment Method",
          description: "Choose how you would like to pay",
          isRequired: true,
          choices: [
            {"Credit Card", "credit_card"},
            {"Bank Transfer", "bank_transfer"},
            {"PayPal", "paypal"}
          ]
        },
        %Instance.Element{
          name: "payment-divider-1",
          type: "html",
          html: "<hr class=\"my-6 border-gray-300\" />"
        },
        # Credit card fields - only visible when payment_method is "credit_card"
        %Instance.Question{
          name: "card_number",
          type: "text",
          title: "Card Number",
          placeholder: "1234 5678 9012 3456",
          description: "Enter your 16-digit card number",
          isRequired: false,
          visibleIf: "{payment_method} = 'credit_card'",
          validators: [
            %Instance.Validator{type: "text", minLength: 13}
          ]
        },
        %Instance.Question{
          name: "card_expiry",
          type: "text",
          title: "Expiry Date",
          placeholder: "MM/YY",
          description: "Card expiration date",
          isRequired: false,
          visibleIf: "{payment_method} = 'credit_card'"
        },
        %Instance.Question{
          name: "card_cvv",
          type: "text",
          title: "CVV",
          placeholder: "123",
          description: "3-digit security code on the back of your card",
          isRequired: false,
          visibleIf: "{payment_method} = 'credit_card'",
          validators: [
            %Instance.Validator{type: "text", minLength: 3, maxLength: 4}
          ]
        },
        # Bank transfer fields - only visible when payment_method is "bank_transfer"
        %Instance.Question{
          name: "account_number",
          type: "text",
          title: "Account Number",
          placeholder: "1234567890",
          description: "Your bank account number",
          isRequired: false,
          visibleIf: "{payment_method} = 'bank_transfer'"
        },
        %Instance.Question{
          name: "routing_number",
          type: "text",
          title: "Routing Number",
          placeholder: "021000021",
          description: "9-digit routing number for your bank",
          isRequired: false,
          visibleIf: "{payment_method} = 'bank_transfer'",
          validators: [
            %Instance.Validator{type: "text", minLength: 9, maxLength: 9}
          ]
        },
        # PayPal email - only visible when payment_method is "paypal"
        %Instance.Question{
          name: "paypal_email",
          type: "text",
          inputType: "email",
          title: "PayPal Email",
          placeholder: "you@example.com",
          description: "Email address associated with your PayPal account",
          isRequired: false,
          visibleIf: "{payment_method} = 'paypal'",
          validators: [
            %Instance.Validator{type: "email"}
          ]
        },
        %Instance.Element{
          name: "payment-divider-2",
          type: "html",
          html: "<hr class=\"my-6 border-gray-300\" />"
        },
        # Amount field - always visible
        %Instance.Question{
          name: "amount",
          type: "text",
          inputType: "number",
          title: "Amount",
          placeholder: "100.00",
          description: "Enter the payment amount in USD",
          isRequired: true,
          validators: [
            %Instance.Validator{type: "numeric", minValue: 0.01, maxValue: 10000}
          ]
        },
        # Save payment method checkbox - always visible
        %Instance.Question{
          name: "save_method",
          type: "boolean",
          title: "Save this payment method for future use",
          description: "Securely store your payment details",
          isRequired: false
        },
        %Instance.Element{
          name: "billing-heading",
          type: "html",
          html: "<h3 class=\"text-xl font-semibold text-gray-900 mt-6\">Billing Information</h3>"
        },
        %Instance.Element{
          name: "billing-address-group",
          type: "panel",
          title: "Billing Address",
          elements: [
            %Instance.Question{
              name: "billing_street",
              type: "text",
              title: "Street Address",
              placeholder: "123 Main St",
              isRequired: true
            },
            %Instance.Question{
              name: "billing_city",
              type: "text",
              title: "City",
              placeholder: "San Francisco",
              isRequired: true
            },
            %Instance.Question{
              name: "billing_state",
              type: "text",
              title: "State",
              placeholder: "CA",
              isRequired: true
            },
            %Instance.Question{
              name: "billing_zip",
              type: "text",
              title: "ZIP Code",
              placeholder: "94102",
              isRequired: true,
              validators: [
                %Instance.Validator{type: "text", minLength: 5, maxLength: 10}
              ]
            }
          ]
        }
      ],
      backend: %Instance.Backend{
        module: Demo.TestBackend,
        function: :submit,
        config: [],
        name: "Test Backend",
        description: "Logs form submissions for testing"
      },
      metadata: %{
        created_at: DateTime.utc_now()
      }
    }
  end

  @doc """
  Returns a form demonstrating panel elements.

  This form demonstrates:
  - Panel elements with titles
  - Panels containing multiple questions
  - Nested panels
  - Conditional panel visibility
  """
  def section_form do
    %Instance{
      id: "section-form",
      title: "Profile Form",
      description: "Complete your profile information using panels.",
      elements: [
        %Instance.Element{
          name: "personal-section",
          type: "panel",
          title: "Personal Information",
          elements: [
            %Instance.Question{
              name: "first_name",
              type: "text",
              title: "First Name",
              placeholder: "John",
              isRequired: true
            },
            %Instance.Question{
              name: "last_name",
              type: "text",
              title: "Last Name",
              placeholder: "Doe",
              isRequired: true
            },
            %Instance.Question{
              name: "email",
              type: "text",
              inputType: "email",
              title: "Email Address",
              placeholder: "john.doe@example.com",
              isRequired: true,
              validators: [
                %Instance.Validator{type: "email"}
              ]
            }
          ]
        },
        %Instance.Element{
          name: "address-section",
          type: "panel",
          title: "Address",
          elements: [
            %Instance.Question{
              name: "street",
              type: "text",
              title: "Street Address",
              placeholder: "123 Main St",
              isRequired: true
            },
            %Instance.Question{
              name: "city",
              type: "text",
              title: "City",
              placeholder: "San Francisco",
              isRequired: true
            },
            %Instance.Question{
              name: "state",
              type: "text",
              title: "State",
              placeholder: "CA",
              isRequired: true
            },
            %Instance.Question{
              name: "zip",
              type: "text",
              title: "ZIP Code",
              placeholder: "94102",
              isRequired: true
            }
          ]
        },
        %Instance.Element{
          name: "preferences-section",
          type: "panel",
          title: "Preferences",
          elements: [
            %Instance.Question{
              name: "newsletter",
              type: "boolean",
              title: "Subscribe to newsletter",
              description: "Receive weekly updates and news"
            },
            %Instance.Question{
              name: "newsletter_frequency",
              type: "dropdown",
              title: "Newsletter Frequency",
              isRequired: false,
              visibleIf: "{newsletter} = true",
              choices: [
                {"Daily", "daily"},
                {"Weekly", "weekly"},
                {"Monthly", "monthly"}
              ]
            },
            %Instance.Question{
              name: "notification_method",
              type: "radiogroup",
              title: "Notification Method",
              description: "Choose how you'd like to receive notifications",
              isRequired: true,
              metadata: %{"style" => "vertical"},
              choices: [
                {"Email Only", "email"},
                {"SMS Only", "sms"},
                {"Both Email and SMS", "both"},
                {"None", "none"}
              ]
            },
            %Instance.Question{
              name: "theme",
              type: "radiogroup",
              title: "Theme Preference",
              description: "Select your preferred color theme",
              isRequired: false,
              metadata: %{"style" => "horizontal"},
              choices: [
                {"Light", "light"},
                {"Dark", "dark"},
                {"Auto", "auto"}
              ]
            }
          ]
        },
        %Instance.Element{
          name: "additional-section",
          type: "panel",
          title: "Additional Information",
          elements: [
            %Instance.Element{
              name: "bio-heading",
              type: "html",
              html: "<h4 class=\"text-lg font-semibold text-gray-900\">Biography</h4>"
            },
            %Instance.Question{
              name: "bio",
              type: "comment",
              title: "Tell us about yourself",
              placeholder: "Write a short bio...",
              isRequired: false
            },
            %Instance.Element{
              name: "social-nested-section",
              type: "panel",
              title: "Social Media Links",
              elements: [
                %Instance.Question{
                  name: "twitter",
                  type: "text",
                  title: "Twitter",
                  placeholder: "@username"
                },
                %Instance.Question{
                  name: "linkedin",
                  type: "text",
                  title: "LinkedIn",
                  placeholder: "linkedin.com/in/username"
                }
              ]
            }
          ]
        },
        %Instance.Element{
          name: "documents-section",
          type: "panel",
          title: "Profile Documents",
          elements: [
            %Instance.Element{
              name: "documents-intro",
              type: "html",
              html:
                "<p class=\"text-gray-600 text-sm mb-4\">Upload any supporting documents for your profile (resume, certifications, etc.)</p>"
            },
            %Instance.Question{
              name: "profile_documents",
              type: "file",
              title: "Documents",
              description: "Upload up to 3 files (PDF, DOC, DOCX, or images - max 10MB each)",
              isRequired: false,
              metadata: %{
                "max_entries" => 3,
                "max_file_size" => 10_000_000,
                "accept" => [".pdf", ".doc", ".docx", "image/*"],
                "presigner" => %{
                  "module" => "Demo.MockUrlPresigner",
                  "function" => "sign"
                },
                "bucket" => "user-profiles",
                "object_name_prefix" => "profile-documents/"
              }
            }
          ]
        }
      ],
      metadata: %{
        created_at: DateTime.utc_now()
      }
    }
  end

  @doc """
  Returns a comprehensive showcase form demonstrating all DynamicForm features.
  Defined as a map (JSON-like format) to demonstrate JSON decoding.
  """
  def showcase_form do
    %{
      "id" => "showcase-form",
      "title" => "DynamicForm Feature Showcase",
      "description" => "A comprehensive example showcasing all DynamicForm capabilities.",
      "elements" => [
        %{
          "name" => "intro-heading",
          "type" => "html",
          "html" =>
            "<h2 class=\"text-2xl font-semibold text-gray-900\">Welcome to DynamicForm</h2>"
        },
        %{
          "name" => "intro-paragraph",
          "type" => "html",
          "html" =>
            "<p class=\"text-gray-600 text-lg mb-4\">This form demonstrates all the features of the DynamicForm library including elements, panels, conditional visibility, and various question types.</p>"
        },
        %{
          "name" => "divider-intro",
          "type" => "html",
          "html" => "<hr class=\"my-6 border-gray-300\" />"
        },
        %{
          "name" => "personal-heading",
          "type" => "html",
          "html" => "<h3 class=\"text-xl font-semibold text-gray-900\">Personal Information</h3>"
        },
        %{
          "name" => "name-panel",
          "type" => "panel",
          "title" => "Full Name",
          "elements" => [
            %{
              "name" => "first_name",
              "type" => "text",
              "title" => "First Name",
              "placeholder" => "John",
              "isRequired" => true,
              "validators" => [
                %{"type" => "text", "minLength" => 2}
              ]
            },
            %{
              "name" => "last_name",
              "type" => "text",
              "title" => "Last Name",
              "placeholder" => "Doe",
              "isRequired" => true,
              "validators" => [
                %{"type" => "text", "minLength" => 2}
              ]
            }
          ]
        },
        %{
          "name" => "email",
          "type" => "text",
          "inputType" => "email",
          "title" => "Email Address",
          "placeholder" => "john.doe@example.com",
          "isRequired" => true,
          "validators" => [
            %{"type" => "email"}
          ]
        },
        %{
          "name" => "email-prefs-panel",
          "type" => "panel",
          "title" => "Email Preferences",
          "visibleIf" => "{email} notempty",
          "elements" => [
            %{
              "name" => "email_notifications",
              "type" => "boolean",
              "title" => "Receive email notifications"
            },
            %{
              "name" => "email_frequency",
              "type" => "dropdown",
              "title" => "Frequency",
              "choices" => [
                %{"value" => "daily", "text" => "Daily"},
                %{"value" => "weekly", "text" => "Weekly"},
                %{"value" => "monthly", "text" => "Monthly"}
              ]
            }
          ]
        },
        %{
          "name" => "divider-1",
          "type" => "html",
          "html" => "<hr class=\"my-6 border-gray-300\" />"
        },
        %{
          "name" => "address-heading",
          "type" => "html",
          "html" => "<h3 class=\"text-xl font-semibold text-gray-900\">Address</h3>"
        },
        %{
          "name" => "street",
          "type" => "text",
          "title" => "Street Address",
          "placeholder" => "123 Main St",
          "isRequired" => true
        },
        %{
          "name" => "city",
          "type" => "text",
          "title" => "City",
          "placeholder" => "San Francisco",
          "isRequired" => true
        },
        %{
          "name" => "state",
          "type" => "text",
          "title" => "State",
          "placeholder" => "CA",
          "isRequired" => true,
          "validators" => [
            %{"type" => "text", "maxLength" => 2}
          ]
        },
        %{
          "name" => "zip",
          "type" => "text",
          "title" => "ZIP",
          "placeholder" => "94102",
          "isRequired" => true,
          "validators" => [
            %{"type" => "text", "minLength" => 5, "maxLength" => 10}
          ]
        },
        %{
          "name" => "divider-2",
          "type" => "html",
          "html" => "<hr class=\"my-6 border-gray-300\" />"
        },
        %{
          "name" => "feedback-heading",
          "type" => "html",
          "html" => "<h3 class=\"text-xl font-semibold text-gray-900\">Feedback</h3>"
        },
        %{
          "name" => "category",
          "type" => "dropdown",
          "title" => "Feedback Category",
          "isRequired" => true,
          "choices" => [
            %{"value" => "bug", "text" => "Bug Report"},
            %{"value" => "feature", "text" => "Feature Request"},
            %{"value" => "general", "text" => "General Feedback"}
          ]
        },
        %{
          "name" => "rating",
          "type" => "text",
          "inputType" => "number",
          "title" => "Rating (1-10)",
          "placeholder" => "8",
          "isRequired" => true,
          "validators" => [
            %{"type" => "numeric", "minValue" => 1, "maxValue" => 10}
          ]
        },
        %{
          "name" => "comments",
          "type" => "comment",
          "title" => "Comments",
          "placeholder" => "Tell us more...",
          "isRequired" => true,
          "validators" => [
            %{"type" => "text", "minLength" => 10, "maxLength" => 500}
          ]
        },
        %{
          "name" => "thank-you",
          "type" => "html",
          "html" =>
            "<p class=\"text-green-600 font-semibold\">Thank you for providing your feedback!</p>",
          "visibleIf" => "{comments} notempty"
        }
      ],
      "backend" => %{
        "module" => "Demo.TestBackend",
        "function" => "submit",
        "config" => [],
        "name" => "Test Backend",
        "description" => "Logs form submissions for testing"
      },
      "metadata" => %{
        "created_at" => DateTime.utc_now()
      }
    }
  end
end
