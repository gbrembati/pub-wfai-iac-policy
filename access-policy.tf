# --- Baseline Access Policy: Workforce AI ---
# First-match evaluation: the rule with the lowest `order` that matches wins.
# Verify this behavior in the Infinity portal after the first apply.

resource "cpwai_workforce_ai_access_rule" "allow_claude" {
  name        = "Allow Claude (Anthropic)"
  description = "Allows access to Claude as an organization-approved AI tool."
  order       = 0
  active      = true

  policy = jsonencode({
    action  = "allow"
    logging = "enabled"
    services_and_application = {
      mode = "selected"
      genai_application = [
        {
          id   = var.claude_app_id
          mode = "all"
        }
      ]
    }
    download_file_protection = "na"
    upload_file_protection   = "na"
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_access_rule" "allow_gemini" {
  name        = "Allow Google Gemini"
  description = "Allows access to Google Gemini as an organization-approved AI tool."
  order       = 1
  active      = true

  policy = jsonencode({
    action  = "allow"
    logging = "enabled"
    services_and_application = {
      mode = "selected"
      genai_application = [
        {
          id   = var.gemini_app_id
          mode = "all"
        }
      ]
    }
    download_file_protection = "na"
    upload_file_protection   = "na"
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

# Catch-all: any other tool in the "Generative AI Tools" category that is not
# explicitly approved requires explicit user confirmation (shadow AI), instead
# of an outright block - chosen for a gradual rollout.
resource "cpwai_workforce_ai_access_rule" "ask_other_genai" {
  name        = "Ask before using unapproved GenAI tools"
  description = "Requires user confirmation for AI tools other than Claude and Gemini."
  order       = 2
  active      = true

  policy = jsonencode({
    action  = "ask"
    logging = "enabled"
    services_and_application = {
      mode = "selected"
      category = [
        { category_id = 60531762 } # Generative AI Tools (wildcard)
      ]
    }
    download_file_protection = "na"
    upload_file_protection   = "na"
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}
