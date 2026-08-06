defmodule Demo.FormInstances do
  @moduledoc """
  Shared form instances used across the demo pages, built as
  SurveyJS-compatible `%DynamicForm.Instance{}` structs.
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
        }
      ],
      metadata: %{
        created_at: DateTime.utc_now()
      }
    }
  end
end
