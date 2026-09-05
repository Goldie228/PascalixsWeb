class MailerService
  # Send email via ActionMailer with optional template rendering
  #
  # @param to [String] recipient email address
  # @param subject [String] email subject line
  # @param template [String, nil] template name (looks up app/views/email_templates/)
  # @param body [String, nil] raw body when not using template
  # @param variables [Hash] template variables for ERB rendering
  def self.send_email(to:, subject:, template: nil, body: nil, variables: {})
    rendered_body = if template
      render_template(template, variables)
    else
      body
    end

    ActionMailer::Base.mail(
      to: to,
      subject: subject,
      body: rendered_body,
      content_type: 'text/html'
    ).deliver_later

    Rails.logger.info "Email sent to #{to}: #{subject}"
  rescue => e
    Rails.logger.error "Failed to send email: #{e.message}"
    raise
  end

  # Render an ERB template from the email_templates directory
  #
  # @param template_name [String] template file name (without extension)
  # @param variables [Hash] local variables for ERB context
  # @return [String] rendered HTML content
  def self.render_template(template_name, variables)
    template_path = Rails.root.join("app/views/email_templates/#{template_name}.html.erb")
    return '' unless File.exist?(template_path)

    # Set instance variables on the binding so ERB can access them as @key
    erb_binding = binding
    variables.each do |key, value|
      erb_binding.local_variable_set("@#{key}", value)
    end

    ERB.new(File.read(template_path)).result(erb_binding)
  end
end
