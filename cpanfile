requires 'Sub::Exporter';
requires 'XSLoader';
requires 'perl', '5.008001';
recommends 'perl', '5.018001';

on configure => sub {
    requires 'Carp';
    requires 'Class::Tiny';
    requires 'Config::AutoConf', '0.19';
    requires 'ExtUtils::MakeMaker', '6.86';
    requires 'Module::Pluggable::Object', '5.1';
};

on build => sub {
    requires 'ExtUtils::MakeMaker';
};

on test => sub {
    requires 'Test::More', '0.9';
};

on develop => sub {
    requires 'Test::CPAN::Changes';
    requires 'Test::CheckManifest';
    requires 'Test::Pod';
    requires 'Test::Pod::Coverage';
    requires 'Test::Pod::Spelling::CommonMistakes';
};
