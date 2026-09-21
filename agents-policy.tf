# --- Baseline Policy: Workforce AI Agents / MCP ---
# Dangerous scenario: an AI agent (e.g. Claude with tools/MCP enabled) connects
# to an unvetted external MCP server and invokes its tools to exfiltrate data or
# perform destructive operations without human supervision.
#
# Intentional ordering (first match wins): the destructive-operations block
# and the unsupervised-UPDATE ask rule are evaluated BEFORE the allow rule
# for internal servers, so they also cover whitelisted internal MCP servers.

resource "cpwai_workforce_ai_agents_rule" "block_destructive_operations" {
  name        = "[Terraform] Block unsupervised destructive tool operations"
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

resource "cpwai_workforce_ai_agents_rule" "ask_on_update_operations" {
  name        = "[Terraform] Ask before unsupervised UPDATE tool operations"
  description = <<-EOT
    Dangerous scenario: an AI agent autonomously invokes an MCP tool with an
    UPDATE operation (e.g. modifying a record, a file, a cloud resource)
    without human supervision. Less severe than DELETE, so this asks for
    confirmation instead of blocking outright. Evaluated before the internal
    allowlist, so it also covers whitelisted internal MCP servers.
  EOT
  order       = 1
  active      = true

  policy = jsonencode({
    action  = "ask"
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
        UPDATE = "match"
        DELETE = "unmatch"
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
  name        = "[Terraform] Allow only internal MCP servers"
  description = "Allows connections only to vetted internal company MCP servers."
  order       = 2
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
  name        = "[Terraform] Block all other MCP servers"
  description = <<-EOT
    Dangerous scenario: an employee connects an unverified third-party MCP
    server (e.g. found in a public repository) to their AI client, which may
    contain malicious or compromised tools (supply chain / tool poisoning).
  EOT
  order       = 3
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
