# Security and Custom Auth Helper

Tina4 uses JWT to encrypt tokens for validation. These tokens are not always practical when doing integrations and
one might want to do other versions of verification.  To this end we can extend the `\Tina4\Auth` class and overwrite 
the core methods.