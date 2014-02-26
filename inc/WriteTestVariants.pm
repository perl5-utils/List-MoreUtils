package WriteTestVariants;

use strict;
use warnings;
use autodie;

use File::Find;
use File::Path;
use File::Basename;
use Module::Pluggable::Object;
use Carp qw(croak);

use lib 'lib';

use Context;
use Data::Tumbler;


use Class::Tiny {

    test_case_default_namespace => sub { croak "No test_case_default_namespace specified" },

    test_case_search_path => sub { [ shift->test_case_default_namespace ] },
    test_case_search_dirs => [ ],
    test_case_search_opts => { },

    initial_path => sub {
        return []
    },
    initial_context => sub {
        use Context;
        return Context->new
    },
    add_context => sub {
        return sub {
            my ($context, $item) = @_;
            return $context->new($context, $item);
        }
    },
};


sub write_test_variants {
    my ($self, $output_dir, $providers) = @_;

    croak "output_test_dir $output_dir already exists"
        if -d $output_dir;

    my $input_tests = $self->get_input_tests();

    my $tumbler = Data::Tumbler->new(
        consumer => sub {
            my ($path, $context, $payload) = @_;
            # payload is a clone of input_tests possibly modified by providers
            $self->write_test_file($path, $context, $payload, $output_dir);
        },
        add_context => $self->add_context,
    );

    $tumbler->tumble(
        $providers,
        $self->initial_path,
        $self->initial_context,
        $input_tests, # payload
    );

    die "No tests written to $output_dir!\n"
        unless -d $output_dir;

    return;
}



# ------


sub get_input_tests {
    my ($self) = @_;

    my @test_case_modules = Module::Pluggable::Object->new(
        require => 0,
        %{$self->test_case_search_opts},
        search_dirs => $self->test_case_search_dirs,
        search_path => $self->test_case_search_path,
    )->plugins;

    my $test_case_default_namespace = $self->test_case_default_namespace || '';
    my $default_prefix_qr = qr/^\Q$test_case_default_namespace\E::/;

    my %input_tests;
    for my $module_name (@test_case_modules) {

        my $test_name = $module_name;
        # remove the namespace prefix for the default set of tests
        $test_name =~ s/$default_prefix_qr//;
        $test_name =~ s{::}{/}g;

        $input_tests{ $test_name } = {
            module => $module_name,
        };
    }

    return \%input_tests;
}



sub write_test_file {
    my ($self, $path, $context, $input_tests, $output_dir) = @_;

    my $base_dir_path = join "/", $output_dir, @$path;

    # note that $testname can include a subdirectory path
    for my $testname (sort keys %$input_tests) {
        my $testinfo = $input_tests->{$testname};

        $testname .= ".t" unless $testname =~ m/\.t$/;
        my $full_path = "$base_dir_path/$testname";
        croak "$full_path already exists" if -e $full_path;
        warn "Writing $full_path\n";

        my $test_script = $self->get_test_file_body($context, $testinfo);

        my $full_dir_path = dirname($full_path);
        mkpath($full_dir_path, 0) unless -d $full_dir_path;

        open my $fh, ">", $full_path;
        print $fh $test_script;
        close $fh;
    }

    return;
}


sub get_test_file_body {
    my ($self, $context, $testinfo) = @_;

    my $pre  = $context->pre_code;
    my $post = $context->post_code;

    my @body;
    push @body, qq{#!perl\n};
    push @body, qq{use lib "lib";\n}; # XXX remove

    push @body, $pre;

    push @body, "require '$testinfo->{require}';\n"
        if $testinfo->{require};

    if (my $module = $testinfo->{module}) {
        push @body, "use lib '$testinfo->{lib}';\n"
            if $testinfo->{lib};
        push @body, "require $module;\n";
        push @body, "$module->run_tests;\n";
    }

    push @body, "$testinfo->{code}\n"
        if $testinfo->{code};

    push @body, $post;

    return join "", @body;
}



1;
