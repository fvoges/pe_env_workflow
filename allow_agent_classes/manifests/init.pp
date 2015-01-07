class allow_agent_classes {
  if $::add_classes {
    include $::add_classes
  }
}
