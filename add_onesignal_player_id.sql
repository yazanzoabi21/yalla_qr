CREATE OR REPLACE FUNCTION update_onesignal_player_id(_player_id text)
RETURNS void AS $$
BEGIN
	UPDATE accounts
	SET onesignal_player_id = _player_id,
	    updated_at = now()
	WHERE owner_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
