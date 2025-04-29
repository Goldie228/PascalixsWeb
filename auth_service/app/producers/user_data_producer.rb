class UserDataProducer
  def self.publish(user)
    Karafka.producer.produce_async(
      topic: 'user_updates',
      payload: {
        event_type: 'user_update',
        user_id: user.id,
        data: user.as_json(include: [:discord_account, :minecraft_account]),
        timestamp: Time.current.to_i
      }.to_json
    )
  end
end