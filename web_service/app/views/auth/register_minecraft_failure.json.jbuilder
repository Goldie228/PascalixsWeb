json.status "error"
json.errors @minecraft_account.errors.messages.transform_keys(&:to_s)
json.message t("controllers.auth.registration_failed")
