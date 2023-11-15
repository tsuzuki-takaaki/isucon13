package Isupipe::Util;
use v5.38;
use utf8;

use Exporter 'import';

our @EXPORT_OK = qw(
    verify_user_session
    DEFAULT_USER_ID_KEY

    encrypt_password
    check_password

    check_params
);

use HTTP::Status qw(:constants);
use Crypt::Eksblowfish::Bcrypt ();
use Crypt::OpenSSL::Random ();
use Type::Params qw(compile);
use Data::Lock qw(dlock);
use Scalar::Util qw(refaddr);

use Isupipe::Assert qw(ASSERT);

use constant DEFAULT_USER_ID_KEY => 'USERID';
use constant BCRYPT_DEFAULT_COST => 4;

sub verify_user_session($app, $c) {
    my $user_id = $c->req->session->{+DEFAULT_USER_ID_KEY};

    unless ($user_id) {
        $c->halt(HTTP_FORBIDDEN, 'failed to get USERID value from session');
    }

    return;
}

sub encrypt_password($password, $cost=undef, $salt=undef) {
    $cost //= BCRYPT_DEFAULT_COST;
    $salt //= Crypt::Eksblowfish::Bcrypt::en_base64(Crypt::OpenSSL::Random::random_bytes(16));
    my $settings = sprintf('$2a$%02d$%s.', $cost, $salt);
    return Crypt::Eksblowfish::Bcrypt::bcrypt($password, $settings)
}

sub check_password {
    my ($plain_password, $hashed_password) = @_;
    if ($hashed_password =~ m!^\$2a\$(\d{2})\$(.+)$!) {
        return encrypt_password($plain_password, $1, $2) eq $hashed_password;
    }
    die "crypt_error";
}

{
    my $compiled_checks = {};

    sub check_params($params, $type) {
        my $check = $compiled_checks->{refaddr($type)} //= compile($type);
        my $flag = $check->($params);

        # 開発環境では、存在しないキーにアクセスした時にエラーになるようにしておく
        if (ASSERT && $flag) {
            dlock($params);
        }

        return $flag
    }
}
