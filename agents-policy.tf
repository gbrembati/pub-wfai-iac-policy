# --- Baseline Policy: Workforce AI Agents / MCP ---
# Dangerous scenario: an AI agent (e.g. Claude with tools/MCP enabled) connects
# to an unvetted external MCP server and invokes its tools to exfiltrate data or
# perform destructive operations without human supervision.
#
# Intentional ordering (first match wins): the destructive-operations block is
# evaluated BEFORE the allow rule for internal servers, so it also covers
# whitelisted internal MCP servers.

resource "cpwai_workforce_ai_agents_rule" "block_destructive_operations" {
  name        = "Block unsupervised destructive tool operations"
  description = <<-EOT
    Dangerous scenario: an AI agent autonomously invokes an MCP tool with a
    destructive operation (DELETE) on a company system - e.g. deleting files,
    DB records, cloud resources - without human supervision. This also applies
    to whitelisted internal MCP servers (see rule ordering).
  EOT
  order       = 0
  active      = true

  policy = jsonencode({
    action  = "block"
    logging = "enabled"
    clients = {
      mode = "all"
    }
    servers = {
      mcp_servers_mode = "all"
    }
    tooling = {
      match_mode = "operations"
      operations = {
        CREATE = "unmatch"
        READ   = "unmatch"
        UPDATE = "unmatch"
        DELETE = "match"
        OTHER  = "unmatch"
      }
    }
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_agents_rule" "allow_internal_mcp_only" {
  name        = "Allow only internal MCP servers"
  description = "Allows connections only to vetted internal company MCP servers."
  order       = 1
  active      = true

  policy = jsonencode({
    action  = "allow"
    logging = "enabled"
    clients = {
      mode = "all"
    }
    servers = {
      mcp_servers_mode = "manual"
      manual = [
        {
          server_type = "remote_server"
          remote_server = {
            match_mode = "domain"
            domain = {
              domain_name = var.internal_mcp_domain
              match_mode  = "any_subdomain"
            }
          }
        }
      ]
    }
    tooling = {
      match_mode = "all"
    }
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}

resource "cpwai_workforce_ai_agents_rule" "block_unlisted_mcp_servers" {
  name        = "Block all other MCP servers"
  description = <<-EOT
    Dangerous scenario: an employee connects an unverified third-party MCP
    server (e.g. found in a public repository) to their AI client, which may
    contain malicious or compromised tools (supply chain / tool poisoning).
  EOT
  order       = 2
  active      = true

  policy = jsonencode({
    action  = "block"
    logging = "enabled"
    clients = {
      mode = "all"
    }
    servers = {
      mcp_servers_mode = "all"
    }
    tooling = {
      match_mode = "all"
    }
  })

  source = [
    {
      assignment_type = "ASSIGNMENT_TYPE_ENTIRE_ORG"
    }
  ]
}
