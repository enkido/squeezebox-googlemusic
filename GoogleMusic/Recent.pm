package Plugins::GoogleMusic::Recent;

use strict;
use warnings;

use Slim::Utils::Cache;
use Slim::Utils::Strings qw(cstring);

use Plugins::GoogleMusic::Plugin;
use Plugins::GoogleMusic::AlbumMenu;
use Plugins::GoogleMusic::ArtistMenu;

tie my %recentSearches, 'Tie::Cache::LRU', 50;
tie my %recentAlbums, 'Tie::Cache::LRU', 50;
tie my %recentArtists, 'Tie::Cache::LRU', 50;

my $cache;

sub init {
	my $recent;

	$cache = Slim::Utils::Cache->new('googlemusic', 3);

	# initialize recent items: need to add them to the LRU cache ordered by timestamp
	$recent = $cache->get('recent_searches');
	map {
		$recentSearches{$_} = $recent->{$_};
	} sort {
		$recent->{$a}->{ts} <=> $recent->{$a}->{ts}
	} keys %$recent;

	$recent = $cache->get('recentAlbums');
	map {
		$recentAlbums{$_} = $recent->{$_};
	} sort {
		$recent->{$a}->{ts} <=> $recent->{$a}->{ts}
	} keys %$recent;

	$recent = $cache->get('recentArtists');
	map {
		$recentArtists{$_} = $recent->{$_};
	} sort {
		$recent->{$a}->{ts} <=> $recent->{$a}->{ts}
	} keys %$recent;

	return;
}

sub recentSearchesAdd {
	my $search = shift;

	return unless $search;

	$recentSearches{$search} = {
		ts => time(),
	};

	$cache->set('recent_searches', \%recentSearches, 'never');

	return;
}

sub recentSearchesMenu {
	my ($client, $callback, $args, $opts) = @_;

	my $recent = [
		sort { lc($a) cmp lc($b) }
		grep { $recentSearches{$_} }
		keys %recentSearches
	];

	my $search_func = $opts->{'all_access'} ?
		\&Plugins::GoogleMusic::Plugin::search_all_access :
		\&Plugins::GoogleMusic::Plugin::search;

	my $items = [];

	foreach (@$recent) {
		push @$items, {
			type => 'link',
			name => $_,
			url  => $search_func,
			passthrough => [ $_ ],
		}
	}

	$items = [ {
		name => cstring($client, 'EMPTY'),
		type => 'text',
	} ] if !scalar @$items;

	$callback->({
		items => $items
	});

	return;
}

sub recentAlbumsAdd {
	my $album = shift;

	return unless $album;

	$recentAlbums{$album->{uri}} = {
		uri => $album->{uri},
		name => $album->{name},
		artist => $album->{artist},
		year => $album->{year},
		cover => $album->{cover},
		ts => time(),
	};

	$cache->set('recentAlbums', \%recentAlbums, 'never');

	return;
}

sub recentAlbumsMenu {
	my ($client, $callback, $args, $opts) = @_;

	my @albums =
		sort { $b->{ts} <=> $a->{ts} or $a->{uri} cmp $b->{uri} }
		grep { $opts->{all_access} ? $_->{uri} =~ '^googlemusic:album:B' : $_->{uri} !~ '^googlemusic:album:B' }
		values %recentAlbums;

	return Plugins::GoogleMusic::AlbumMenu::menu($client, $callback, $args, \@albums, $opts);
}

sub recentArtistsAdd {
	my $artist = shift;

	return unless $artist;

	my $image = $artist->{image};

	if ($image =~ '^/html/images/' && $artist->{uri} =~ '^googlemusic:artist:A') {
		$image = Plugins::GoogleMusic::AllAccess::get_artist_image($artist->{uri});
		$image = Plugins::GoogleMusic::Image->uri($image);
	}

	$recentArtists{$artist->{uri}} = {
		uri => $artist->{uri},
		name => $artist->{name},
		image => $image,
		ts => time(),
	};

	$cache->set('recentArtists', \%recentArtists, 'never');

	return;
}

sub recentArtistsMenu {
	my ($client, $callback, $args, $opts) = @_;

	my @artists = 
		sort { $b->{ts} <=> $a->{ts} or $a->{uri} cmp $b->{uri} } 
		grep { $opts->{all_access} ? $_->{uri} =~ '^googlemusic:artist:A' : $_->{uri} !~ '^googlemusic:artist:A' }
		values %recentArtists;

	return Plugins::GoogleMusic::ArtistMenu::menu($client, $callback, $args, \@artists, $opts);
}


1;
