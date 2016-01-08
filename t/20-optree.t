use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use Test::More tests => 15;

use Fcntl qw(:flock :DEFAULT SEEK_SET SEEK_CUR SEEK_END);

subtest construction => sub {
    plan tests => 4;

    sub scalar_assignment {
        my $a = 1;
    }

    my $ops = _get_optree_for_sub_named('scalar_assignment');
    ok($ops, 'create optree');
    my $count = 0;
    $ops->walk_inorder(sub { $count++ });
    ok($count > 1, 'More than one op is part of scalar_assignment');

    is($ops->deparse, '$a = 1', 'scalar_assignment');

    sub multi_statement_scalar_assignment {
        my $a = 1;
        my $b = 2;
    }
    is(_get_optree_for_sub_named('multi_statement_scalar_assignment')->deparse,
        join("\n", q($a = 1;), q($b = 2)),
        'multi_statement_scalar_assignment');
};

subtest 'assignment' => sub {
    _run_tests(
        list_assignment => join("\n", q(my @a = (1, 2);),
                                      q(our @b = (3, 4);),
                                      q(@a = @b;),
                                      q(my($a, $b) = (@a, @b);),
                                      q(@a = (@b, @a)),
            ),
        list_index_assignment => join("\n", q(my @the_list;),
                                            q(my $idx;),
                                            q($the_list[2] = 'foo';),
                                            q($the_list[$idx] = 'bar')),

        list_slice_assignment => join("\n", q(my @the_list;),
                                            q(my $idx;),
                                            q(my @other_list;),
                                            q(@the_list[1, $idx, 3, @other_list] = @other_list[1, 2, 3])),
        # These hash assigments are done with aassign, so there's no way to
        # tell that the lists would look better as ( one => 1, two => 2 )
        hash_assignment => join("\n",   q(my %a = ('one', 1, 'two', 2);),
                                        q(our %b = ('three', 3, 'four', 4);),
                                        q(%a = %b;),
                                        q(%a = (%b, %a))),
        hash_slice_assignment => join("\n", q(my %the_hash;),
                                            q(my @indexes;),
                                            q(@the_hash{'1', 'key', @indexes} = (1, 2, 3))),

        scalar_ref_assignment => join("\n", q(my $a = 1;),
                                            q(our $b = \$a;),
                                            q($$b = 2)),

        array_ref_assignment => join("\n",  q(my $a = [1, 2];),
                                            q(@$a = (1, 2))),
        array_ref_slice_assignment => join("\n",    q(my $list;),
                                                    q(my $other_list;),
                                                    q(@$list[1, @$other_list] = (1, 2, 3))),

        hash_ref_assignment => join("\n",   q(my $a = {1 => 1, two => 2};),
                                            q(%$a = ('one', 1, 'two', 2))),
        hasf_ref_slice_assignment => join("\n", q(my $hash = {};),
                                                q(my @list;),
                                                q(@$hash{'one', @list, 'last'} = @list)),
    );
};

subtest 'conditional' => sub {
    _run_tests(
        'num_lt' => join("\n",  q(my $a = 1;),
                                q(my $result = $a < 5)),
        'num_gt' => join("\n",  q(my $a = 1;),
                                q(my $result = $a > 5)),
        'num_eq' => join("\n",  q(my $a = 1;),
                                q(my $result = $a == 5)),
        'num_ne' => join("\n",  q(my $a = 1;),
                                q(my $result = $a != 5)),
        'num_le' => join("\n",  q(my $a = 1;),
                                q(my $result = $a <= 5)),
        'num_cmp' => join("\n", q(my $a = 1;),
                                q(my $result = $a <=> 5)),
        'num_ge' => join("\n",  q(my $a = 1;),
                                q(my $result = $a >= 5)),
        'str_lt' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a lt 'five')),
        'str_gt' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a gt 'five')),
        'str_eq' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a eq 'five')),
        'str_ne' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a ne 'five')),
        'str_le' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a le 'five')),
        'str_ge' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a ge 'five')),
        'str_cmp' => join("\n", q(my $a = 1;),
                                q(my $result = $a cmp 5)),
    );
};

subtest 'subroutine call' => sub {
    _run_tests(
        'call_sub' => join("\n",    q(foo(1, 2, 3))),
        'call_subref' => join("\n", q(my $a;),
                                    q($a->(1, 'two', 3))),
        'call_subref_from_array' => join("\n",  q(my @a;),
                                                q($a[0]->(1, 'two', 3))),
        'call_sub_from_package' => q(Some::Other::Package::foo(1, 2, 3)),
        'call_class_method_from_package' => q(Some::Other::Package->foo(1, 2, 3)),
        'call_instance_method' => join("\n",    q(my $obj;),
                                                q($obj->foo(1, 2, 3))),
        'call_instance_variable_method' => join("\n",   q(my $obj;),
                                                        q(my $method;),
                                                        q($obj->$method(1, 2, 3))),
        'call_class_variable_method' => join("\n",  q(my $method;),
                                                    q(Some::Other::Package->$method(1, 2, 3))),
    );
};

subtest 'eval' => sub {
    _run_tests(
        'const_string_eval' => q(eval('this is a string')),
        'var_string_eval' => join("\n", q(my $a;),
                                        q(eval();),
                                        q(eval($a))),
        'block_eval' => join("\n",  q(my $a;),
                                    q(eval {),
                                    q(    $a = 1;),
                                    q(    $a),
                                    q(})),
    );
};

subtest 'string functions' => sub {
    _run_tests(
        crypt_fcn => join("\n", q(my $a;),
                                q(crypt($a, 'salt'))),
        index_fcn => join("\n", q(my $a;),
                                q($a = index($a, 'foo');),
                                q(index($a, 'foo', 1))),
        rindex_fcn  => join("\n",   q(my $a;),
                                    q($a = rindex($a, 'foo');),
                                    q(index($a, 'foo', 1))),
        substr_fcn  => join("\n",   q(my $a;),
                                    q($a = substr($a, 1, 2, 'foo');),
                                    q(substr($a, 2, 3) = 'bar')),
        sprintf_fcn => join("\n",   q(my $a;),
                                    q($a = sprintf($a, 1, 2, 3))),
        quote_qq    => join("\n",   q(my $a = 'hi there';),
                                    q(my $b = qq(Joe, $a, this is a string blah blah\n\cP\x{1f});),
                                    q($b = $a . $a;),
                                    q($b = qq($b $b))),
        pack_fcn  => join("\n", q(my $a;),
                                q($a = pack($a, 1, 2, 3))),
        unpack_fcn => join("\n",q(my $a;),
                                q($a = unpack($a);),
                                q($a = unpack('%32b', $a);),
                                q($a = unpack($a, $a))),
        reverse_fcn => join("\n",   q(my $a;),
                                    q($a = reverse(@_);),
                                    q($a = reverse($a);),
                                    q(scalar(reverse(@_));),
                                    q(my @a;),
                                    q(@a = reverse(@_);),
                                    q(@a = reverse(@a))),
        tr_operator => join("\n",   q(my $a;),
                                    q($a = tr/$a/zyxw/cdsr)),
        quotemeta_fcn => join("\n", q(my $a;),
                                    q($a = quotemeta();),
                                    q($a = quotemeta($a);),
                                    q(quotemeta($a))),
        vec_fcn => join("\n",       q(my $a = vec('abcdef', 1, 4);),
                                    q(vec($a, 2, 2) = 4)),
        map { ( "${_}_dfl"      => "$_()",
                "${_}_to_var"   => join("\n",   q(my $a;),
                                                "\$a = $_()"),
                "${_}_on_val"   => join("\n",   q(my $a;),
                                                "$_(\$a)")
              )
            } qw( chomp chop chr hex lc lcfirst uc ucfirst length oct ord ),
    );
};

subtest regex => sub {
    _run_tests(
        anon_regex => join("\n",    q(my $a = qr/abc\w(\s+)/ims;),
                                    q(my $b = qr/abc),
                                    q(           \w),
                                    q(           $a),
                                    q(           (\s+)/iox)),
        match       => join("\n",   q(m/abc/;),
                                    q(our $a;),
                                    q($a =~ m/abc/;),
                                    q(my $rx = qr/def/;),
                                    q(my($b) = $a !~ m/abc$rx/i;),
                                    q(my($c) = m/$rx def/x;),
                                    q($c = $1)),
        substitute  => join("\n",   q(s/abc/def/i;),
                                    q(my $a;),
                                    q($a =~ s/abc/def/;),
                                    q($a =~ s/abc/def$a/;),
                                    q(my $rx = qr/def/;),
                                    q(s/abd $rx/def/x;),
                                    q($a =~ s/abd $rx/def/x)),
    );
};

subtest numeric => sub {
    _run_tests(
        atan2_func => join("\n",    q(my($a, $b);),
                                    q($a = atan2($a, $b))),
        map { ( "${_}_func" => join("\n", q(my $a;),
                                        "\$a = $_();",
                                        "\$a = $_(\$a);",
                                        "$_(\$a)")
              )
            } qw(abs cos exp int log rand sin sqrt srand),
    );
};

subtest 'array functions' => sub {
    _run_tests(
        pop_fcn => join("\n",   q(my($a, @list);),
                                q($a = pop(@list);),
                                q(pop(@list);),
                                q($a = pop())),
        push_fcn => join("\n",  q(my($a, @list);),
                                q(push(@list, 1, 2, 3);),
                                q($a = push(@list, 1))),
        shift_fcn => join("\n", q(my($a, @list);),
                                q($a = shift(@list);),
                                q(shift(@list);),
                                q($a = shift())),
        unshift_fcn => join("\n",   q(my($a, @list);),
                                    q(unshift(@list, 1, 2, 3);),
                                    q($a = unshift(@list, 1))),
        splice_fcn => join("\n",q(my($a, @list, @rv);),
                                q($a = splice(@list);),
                                q(@rv = splice(@list, 1);),
                                q(@rv = splice(@list, 1, 2);),
                                q(@rv = splice(@list, 1, 2, @rv);),
                                q(@rv = splice(@list, 1, 2, 3, 4, 5))),
        array_len => join("\n", q(my($a, @list, $listref);),
                                q($a = $#list;),
                                q($a = $#$listref;),
                                q($a = scalar(@list))),
        join_fcn => join("\n",  q(my($a, @list);),
                                q($a = join(',', 2, 3, 4);),
                                q($a = join("\n", 2, 3, 4);),
                                q($a = join(1, @list);),
                                q(join(@list))),
    );
};

subtest 'sort/map/grep' => sub {
    _run_tests(
        map_fcn => join("\n",  q(my($a, @list);),
                                q(map(chr(), $a, $a);),
                                q(map(chr(), @list);),
                                q(map { chr() } ($a, $a);),
                                q(map { chr() } @list)),
        grep_fcn => join("\n",  q(my($a, @list);),
                                q(grep(m/a/, $a, $a);),
                                q(grep(m/a/, @list);),
                                q(grep { m/a/ } ($a, $a);),
                                q(grep { m/a/ } @list)),
        sort_fcn => join("\n",  q(my(@a, $subref, $val);),
                                q(@a = sort @a;),
                                q(@a = sort ($val, @a);),
                                q(@a = sort { 1 } @a;),
                                q(@a = sort { ; } @a;),
                                q(@a = sort { $a <=> $b } @a;),
                                q(@a = sort { $b <=> $a } @a;),
                                q(@a = sort { $b cmp $a } @a;),
                                q(@a = reverse(sort { $b cmp $a } @a);),
                                q(@a = sort scalar_assignment @a;),
                                q(@a = sort $subref @a)),
    );
};

subtest 'hash functions' => sub {
    _run_tests(
        delete_hash => join("\n",   q(our %hash;),
                                    q(my $a = delete($hash{'foo'});),
                                    q(my @a = delete(@hash{'foo', 'bar'});),
                                    q(@a = delete(@hash{@a});),
                                    q(delete(@hash{@a});),
                                    q(delete(local @hash{@a}))),
        delete_array => join("\n",  q(our @array;),
                                    q(my $a = delete($array[1]);),
                                    q(my @a = delete(@array[1, 2]);),
                                    q(@a = delete(@array[@a]);),
                                    q(delete(local @array[@a])),),
        exists_hash => join("\n",   q(my %hash;),
                                    q(my $a = exists($hash{'foo'}))),
        exists_array => join("\n",  q(my @array;),
                                    q(my $a = exists($array[1]))),
        exists_sub => q(my $a = exists(&scalar_assignment)),
        each_fcn => join("\n",  q(my %h;),
                                q(my($k, $v) = each(%h))),
        keys_fcn => join("\n",  q(my %h;),
                                q(my @keys = keys(%h))),
        values_fcn => join("\n",q(my %h;),
                                q(my @vals = values(%h))),
    );
};

subtest 'user/group info' => sub {
    _run_tests(
        getgrent_fcn => join("\n",  q(my $a = getgrent();),
                                    q($a = getgrent())),
        endhostent_fcn =>   q(endhostent()),
        endnetent_fcn =>    q(endnetent()),
        endpwent_fcn =>     q(endpwent()),
        setpwent_fcn =>     q(setpwent()),
        endgrent_fcn =>     q(endgrent()),
        setgrent_fcn =>     q(setgrent()),
        getlogin_fcn =>     q(my $a = getlogin()),
        getgrgid_fcn => join("\n",  q(my $gid;),
                                    q(my $a = getgrgid($gid))),
        getgrnam_fcn => join("\n",  q(my $name;),
                                    q(my $a = getgrnam($name))),
        getpwent_fcn => join("\n",  q(my $name = getpwent();),
                                    q(my @info = getpwent();),
                                    q(my($n, $pass, $uid, $gid) = getpwent())),
        getpwnam_fcn => join("\n",  q(my $gid = getpwnam('root');),
                                    q(my @info = getpwnam('root');),
                                    q(my($name, $pass, $uid, $g) = getpwnam('root'))),
        getpwuid_fcn => join("\n",  q(my $name = getpwuid(0);),
                                    q(my @info = getpwuid(0);),
                                    q(my($n, $pass, $uid, $gid) = getpwuid(0))),
    );
};

subtest 'I/O' => sub {
    _run_tests(
        binmode_fcn => join("\n",   q(binmode(F);),
                                    q(binmode(*F, ':raw');),
                                    q(binmode(F, ':crlf');),
                                    q(my $fh;),
                                    q(binmode($fh);),
                                    q(binmode(*$fh, ':raw');),
                                    q(binmode($fh, ':crlf'))),
        close_fcn => join("\n",     q(close(F);),
                                    q(close(*G);),
                                    q(my $f;),
                                    q(close($f);),
                                    q(close(*$f);),
                                    q(close())),
        closedir_fcn => join("\n",  q(closedir(D);),
                                    q(closedir(*D);),
                                    q(my $d;),
                                    q(closedir($d);),
                                    q(closedir(*$d))),
        dbmclose_fcn => join("\n",  q(my %h;),
                                    q(dbmclose(%h))),
        dbmopen_fcn => join("\n",   q(my %h;),
                                    q(dbmopen(%h, '/some/path/name', 0666))),
        die_fcn => q(die('some list', 'of things', 1, 1.234)),
        warn_fcn => join("\n",  q(warn('some list', 'of things', 1, 1.234);),
                                q(warn())),
        eof_fcn => join("\n",   q(my $a = eof(F);),
                                q($a = eof(*F);),
                                q(my $f;),
                                q($a = eof($f);),
                                q($a = eof(*$f);),
                                q($a = eof;),
                                q($a = eof())),
        fileno_fcn => join("\n",    q(my $a = fileno(F);),
                                    q(my $f;),
                                    q($a = fileno(*$f))),
        flock_fcn => join("\n",     q(my $a = flock(F, LOCK_SH | LOCK_NB);),
                                    q($a = flock(*F, LOCK_EX | LOCK_NB);),
                                    q(my $f;),
                                    q($a = flock($f, LOCK_UN);),
                                    q($a = flock(*$f, LOCK_UN | LOCK_NB))),
        getc_fcn => join("\n",      q(my $a = getc(F);),
                                    q($a = getc())),
        print_fcn => join("\n",     q(my $a = print();),
                                    q(print('foo bar', 'baz', "\n");),
                                    q(print F ('foo bar', 'baz', "\n");),
                                    q(my $f;),
                                    q(print { $f } ('foo bar', 'baz', "\n");),
                                    q(print { *$f } ('foo bar', 'baz', "\n"))),
        printf_fcn => join("\n",    q(printf F ($a, 'foo', 'bar');),
                                    q(printf($a, 'foo', 'bar'))),
        read_fcn => join("\n",      q(my($fh, $buf);),
                                    q(my $bytes = read(F, $buf, 10);),
                                    q(read(*$fh, $buf, 10, 5);),
                                    q(read(*F, $buf, 10, -5))),
        sysread_fcn => join("\n",   q(my($fh, $buf);),
                                    q(my $bytes = sysread(F, $buf, 10);),
                                    q(sysread(*$fh, $buf, 10, 5);),
                                    q(sysread(*F, $buf, 10, -5))),
        syswrite_fcn => join("\n",  q(my($fh, $buf);),
                                    q(my $bytes = syswrite(F, $buf, 10, 5);),
                                    q($bytes = syswrite(*F, $buf, 10);),
                                    q(syswrite($fh, $buf);),
                                    q(syswrite(*$fh, $buf))),
        readdir_fcn => join("\n",   q(my $d;),
                                    q(my $dir = readdir(D);),
                                    q($dir = readdir(*D);),
                                    q($dir = readdir($d);),
                                    q($dir = readdir(*$d))),
        readline_fcn => join("\n",  q(my $line = <ARGV>;),
                                    q($line = readline(*F);),
                                    q($line = <F>;),
                                    q(my $fh;),
                                    q($line = <$fh>;),
                                    q(my @lines = readline($fh);),
                                    q(@lines = readline(*$fh);),
                                    q(@lines = <$fh>)),
        rewinddir_fcn =>    q(rewinddir(D)),
        seekdir_fcn =>      q(seekdir(D, 10)),
        seek_fcn => join("\n",      q(my $a = seek(F, 10, SEEK_CUR);),
                                    q(my $fh;),
                                    q(seek($fh, -10, SEEK_END);),
                                    q(seek(*$fh, 0, SEEK_SET))),
        sysseek_fcn => join("\n",   q(my $a = sysseek(F, 10, SEEK_CUR);),
                                    q(my $fh;),
                                    q(sysseek($fh, -10, SEEK_END);),
                                    q(sysseek(*$fh, 0, SEEK_SET))),
        tell_fcn => join("\n",      q(my $a = tell(F);),
                                    q($a = tell(*F);),
                                    q($a = tell();),
                                    q(my $fh;),
                                    q($a = tell($fh);),
                                    q($a = tell(*$fh))),
        telldir_fcn => join("\n",   q(my $a = telldir(D);),
                                    q($a = telldir(*D);),
                                    q(my $dh;),
                                    q($a = telldir($dh);),
                                    q($a = telldir(*$dh))),
        syscall_fcn => join("\n",   q(my $a = syscall(1, 2, 3);),
                                    q(my $str = 'foo';),
                                    q($a = syscall(4, $str, 5))),
        truncate_fcn => join("\n",  q(my $a = truncate(F, 10);),
                                    q($a = truncate(*F, 11);),
                                    q(my($fh, %h);),
                                    q(truncate($fh, 12);),
                                    q(truncate($h{'foo'}, 14))),
        write_fcn => join("\n",     q(write(F);),
                                    q(write(*F);),
                                    q(my $fh;),
                                    q(write($fh);),
                                    q(write())),
        select_fh => join("\n",     q(my $fh = select();),
                                    q(select(F);),
                                    q(select(*F);),
                                    q(select($fh);),
                                    q(select(*$fh))),
        select_sycall => join("\n", q(my($found, $time) = select(*F, 1, 2, 3);),
                                    q($found = select(*F, 1, 2, 3);),
                                    q(my $fh;),
                                    q(($found, $time) = select($fh, 1, 2, 3);),
                                    q($found = select(*$fh, 1, 2, 3))),
    );
};

subtest 'files' => sub {
    _run_tests(
        file_tests =>   join("\n",  q(my $fh;),
                                    q(my $a = -r *F;),
                                    q($a = -w '/some/path/name';),
                                    q($a = -x $fh;),
                                    q($a = -o;),
                                    q($a = -R _;),
                                    q($a = -W $fh;),
                                    q($a = -X *F;),
                                    q($a = -O '/some/file/name';),
                                    q($a = -e;),
                                    q($a = -z _;),
                                    q($a = -s '/some/file/name';),
                                    q($a = -f $fh;),
                                    q($a = -d *F;),
                                    q($a = -l;),
                                    q($a = -p _;),
                                    q($a = -S *F;),
                                    q($a = -b '/some/file/name';),
                                    q($a = -c $fh;),
                                    q($a = -t _;),
                                    q($a = -u;),
                                    q($a = -g $fh;),
                                    q($a = -k *F;),
                                    q($a = -T '/some/file/name';),
                                    q($a = -B;),
                                    q($a = -M _;),
                                    q($a = -A '/some/file/name';),
                                    q($a = -C $fh)),
        chdir_expr => join("\n",    q(my $a = chdir('/some/path/name');),
                                    q($a = chdir())),
        chdir_fh => q(chdir(*F)),
        chmod_fcn => join("\n",     q(my $a = chmod(0755, '/some/file/name', '/other/file');),
                                    q(chmod(04322, 'foo'))),
        chown_fcn => join("\n",     q(my $a = chown(0, 3, '/some/file/name', '/other/file');),
                                    q(chown(1, 999, 'foo'))),
        chroot_fcn => join("\n",    q(my $a = chroot('/some/file/name');),
                                    q(chroot())),
        fcntl_fcn => join("\n",     q(my $a = fcntl(F, 1, 2);),
                                    q(fcntl(*F, 2, 'foo');),
                                    q(my($fh, $buf);),
                                    q(fcntl($fh, 3, $buf);),
                                    q(fcntl(*$fh, 4, 0))),
        glob_fcn =>     join("\n",  q(my @files = glob('some *patterns{one,two}');),
                                    q(my $file = glob('*.c');),
                                    q($file = glob('*.h'))),
        ioctl_fcn => join("\n",     q(my($a, $fh);),
                                    q(my $rv = ioctl(F, 1, $a);),
                                    q($rv = ioctl(*F, 2, $a);),
                                    q(ioctl($fh, 3, $a);),
                                    q($rv = ioctl(*$fh, 4, $a))),
        link_fcn => join("\n",  q(my $a = link('/old/path', '/new/path');),
                                q($a = link($a, '/foo/bar'))),
        mkdir_fcn => join("\n", q(my $a = mkdir('/some/path', 0755);),
                                q(mkdir();),
                                q($a = mkdir('/other/path'))),
        open_fcn => join("\n",  q(my $rv = open(F, 'some/path');),
                                q($rv = open(*F, 'r', '/some/path');),
                                q(open(F);),
                                q(open(my $fh, '|-', '/some/command', '-a', '-b');),
                                q(open(*$fh, '>:raw:perlio:encoding(utf-16le):crlf', 'filename.ext'))),
        opendir_fcn => join("\n",   q(my $rv = opendir(D, '/path/name');),
                                    q($rv = opendir(*D, '/path/name');),
                                    q($rv = opendir(my $dh, '/path/name');),
                                    q($rv = opendir(*$dh, '/path/name'))),
        readlink_fcn => join("\n",  q(my $rv = readlink('/path/name');),
                                    q(readlink())),
        rename_fcn =>   q(my $rv = rename('/old/path/name', '/new/name')),
        rmdir_fcn => join("\n", q(my $rv = rmdir('/path/name');),
                                q($rv = rmdir())),
        stat_fcn => join("\n",  q(my @rv = stat(F);),
                                q(@rv = stat(*F);),
                                q(@rv = stat(_);),
                                q(my $fh;),
                                q(my($dev, $ino, undef, $nlink) = stat($fh);),
                                q(@rv = stat(*$fh);),
                                q(stat();),
                                q(stat('/path/to/file'))),
        lstat_fcn => join("\n", q(my @rv = lstat(F);),
                                q(@rv = lstat(*F);),
                                q(@rv = lstat(_);),
                                q(my $fh;),
                                q(my($dev, $ino, undef, $nlink) = lstat($fh);),
                                q(@rv = lstat(*$fh);),
                                q(lstat();),
                                q(lstat('/path/to/file'))),
        link_fcn => join("\n",  q(my $rv = link('/file/name', '/link/name');),
                                q($rv = link('/other_file', 'new_link'))),
        symlink_fcn => join("\n",   q(my $rv = symlink('/file/name', '/link/name');),
                                    q($rv = symlink('/other_file', 'new_link'))),
        sysopen_fcn => join("\n",   q(my $rv = sysopen(F, '/path/name', O_RDONLY);),
                                    q($rv = sysopen(*F, '/path_name', O_RDWR | O_TRUNC);),
                                    q(sysopen(my $fh, '/path/name', O_WRONLY | O_CREAT, 0777);),
                                    q(sysopen(*$fh, '/path/name', O_WRONLY | O_CREAT | O_EXCL))),
        umask_fcn => join("\n", q(my $mask = umask();),
                                q(umask(0775))),
        unlink_fcn => join("\n",    q(my $rv = unlink('/path/name', '/file/name');),
                                    q(my($a, $b);),
                                    q($rv = unlink($a, $b))),
        utime_fcn => join("\n",     q(my $rv = utime(undef, undef, '/path/name', '/file_name');),
                                    q(my($a, $b);),
                                    q($rv = utime(123, 456, $a, $b))),
    );
};

subtest operators => sub {
    _run_tests(
        undef_op => join("\n",  q(my $a = undef;),
                                q(undef($a);),
                                q(my(@a, %a);),
                                q(undef($a[1]);),
                                q(undef($a{'foo'});),
                                q(undef(@a);),
                                q(undef(%a);),
                                q(undef(&some::function::name))),
        add_op => join("\n",    q(my($a, $b);),
                                q($a = $a + $b;),
                                q($b = $a + $b + 1)),
        sub_op => join("\n",    q(my($a, $b);),
                                q($a = $a - $b;),
                                q($b = $a - $b - 1)),
        mul_op => join("\n",    q(my($a, $b);),
                                q($a = $a * $b;),
                                q($b = $a * $b * 2)),
        div_op => join("\n",    q(my($a, $b);),
                                q($a = $a / $b;),
                                q($b = $a / $b / 2)),
        mod_op => join("\n",    q(my($a, $b);),
                                q($a = $a % $b;),
                                q($b = $a % $b % 2)),
        preinc_op => join("\n", q(my $a = 4;),
                                q(my $b = ++$a)),
        postinc_op => join("\n",q(my $a = 4;),
                                q(my $b = $a++)),
        bin_negate => join("\n",q(my $a = 3;),
                                q(my $b = ~$a;),
                                q($a = ~$b)),
        deref_op => join("\n",  q(my $a;),
                                q(our $b;),
                                q($a = $a->{'foo'};),
                                q($a = $b->{'foo'}->[2];),
                                q($a = @{ $a->{'foo'}->[3]->{'bar'} };),
                                q($a = %{ $b->[2]->{'foo'}->[4] };),
                                q($a = ${ $a->{'foo'}->[5]->{'bar'} };),
                                q($a = *{ $b->[$a]->{'foo'}->[5] };),
                                q($a = $$a;),
                                q($b = $$b)),
        pow_op => join("\n",    q(my $a;),
                                q($a = 3 ** $a)),
        log_negate => join("\n",q(my $a = 1;),
                                q($a = !$a)),
        repeat => join("\n",    q(my $a;),
                                q($a = $a x 10;),
                                q(my @a = (1, 2, 3) x $a)),
        shift_left => join("\n",q(my $a;),
                                q($a = $a << 1;),
                                q($a = $a << $a)),
        shift_right => join("\n",q(my $a;),
                                q($a = $a >> 1;),
                                q($a = $a >> $a)),
        bit_and => join("\n",   q(my $a;),
                                q($a = $a & 1;),
                                q(my $b = $a & 3 & $a)),
        bit_or => join("\n",    q(my $a;),
                                q($a = $a | 1;),
                                q(my $b = $a | 3 | $a)),
        bit_xor => join("\n",   q(my $a;),
                                q($a = $a ^ 1)),
        log_and => join("\n",   q(my $a;),
                                q(our $b;),
                                q($a = $a && $b;),
                                q($b = $b && $a)),
        log_or => join("\n",    q(my $a;),
                                q(our $b;),
                                q($a = $a || $b;),
                                q($b = $b || $a)),
        log_xor => join("\n",   q(my $a;),
                                q(our $b;),
                                q($a = $a xor $b;),
                                q($b = $b xor $a)),
        assignment_ops => join("\n",    q(my $a;),
                                        q(our $b;),
                                        q($a += $b + 1;),
                                        q($b -= $b - 1;),
                                        q($a *= $b + 1;),
                                        q($a /= $b - 1;),
                                        q($a .= $b . 'hello';),
                                        q($a **= $b + 1;),
                                        q($a &= $b;),
                                        q($a &&= $b;),
                                        q($b ||= $a;),
                                        q($b |= 1;),
                                        q($a ^= $b;),
                                        q($a <<= $b;),
                                        q($b >>= $a)),
        conditional_op => join("\n",    q(my($a, $b);),
                                        q($a = $b ? $a : 1)),
        flip_flop => join("\n",     q(my($a, $b);),
                                    q($a = $a .. $b;),
                                    q($a = $a ... $b)),
    );
};

# test different dereferences
# @{$a->{key}->[1]}

# Tests for 5.10
# say

# Tests for 5.12
# keys/values/each work on arrays

# Tests for 5.14
# keys/values/each/pop/push/shift/unshift/splice work on array/hash-refs

# Tests for 5.18
# each() assigns to $_ in a lone while test

sub _run_tests {
    my %tests = @_;
    plan tests => scalar keys %tests;

    foreach my $test_name ( keys %tests ) {
        my $code = $tests{$test_name};
        eval "sub $test_name { $code }";
        (my $expected = $code) =~ s/my(?: )?|our(?: )? //g;
        if ($@) {
            die "Couldn't compile code for $test_name: $@";
        }
        my $ops = _get_optree_for_sub_named($test_name);
        is(eval { $ops->deparse }, $expected, "code for $test_name")
            || do {
                diag("\$\@: $@\nTree:\n");
                $ops->print_as_tree
            };
    }
}


sub _get_optree_for_sub_named {
    my $subname = shift;
    Devel::Chitin::OpTree->build_from_location(
        Devel::Chitin::Location->new(
            package => 'main',
            subroutine => $subname,
            filename => __FILE__,
            line => 1,
        )
    );
}
