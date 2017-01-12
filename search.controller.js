delivery_app.controller('FlightsSearchController', [
  '$state',
  '$uibModal',
  'FlightService',
  'FLIGHTS',
  'StoreService',
  'FlightSession',
  'PortBiletErrorService',
  'UfsBtsp',
  function($state, $uibModal, FlightService, FLIGHTS, StoreService, FlightSession, PortBiletErrorService, UfsBtsp){
    var self = this;

    self.params = FlightSession.get('search');
    self.service_classes = FLIGHTS['SERVICE_CLASSES'];

    if (self.params) {
      self.type = self.params.type;
      self.segments = [];
      if (self.type == 'only') {
        var s = self.params.route.segment;
        self.segments = [{from: s[0].locationBegin, to: s[0].locationEnd, s_date: null, e_date: null}];
      }
      if (self.type == 'both') {
        var s = self.params.route.segment;
        self.segments = [{from: s[0].locationBegin, to: s[0].locationEnd, s_date: null, e_date: null}];
      }
      if (self.type == 'complex') {
        angular.forEach(self.params.route.segment, function(s){
          self.segments.push({from: s.locationBegin, to: s.locationEnd, s_date: null, e_date: null});
        });
      }
      self.passengers = {};
      self.service_class = self.params.serviceClass;
      self.skip_connected = self.params.skipConnected;
      self.etickets_only = self.params.eticketsOnly;
    }else{
      self.type = 'only';
      self.segments = [{from: null,to: null,s_date: null,e_date: null}];
      self.passengers = {};
      self.service_class = 'ECONOMY';
      self.skip_connected = true;
      self.etickets_only = false;
    }

    self.loadAirports = function(val) { return FlightService.airports(val); };
    
    self.activeType = function(type){
      return self.type == type;
    };

    self.switchType = function(type){
      self.type = type;
    };

    self.hintOpen = function($event, hint){
      $event.preventDefault();
      $uibModal.open({
        animation: true,
        size: 'lg',
        templateUrl: 'delivery/flights/hints/' + hint + '.html',
        controller: 'RailwaysHintController'
      });
    };

    self.exchange = function($event, index){
      $event.preventDefault();
      var from = self.segments[index].from;
      self.segments[index].from = self.segments[index].to;
      self.segments[index].to = from;
    };

    self.remove = function($event, index){
      $event.preventDefault();
      self.segments.splice(index, 1);
    };

    self.add = function($event){
      $event.preventDefault();
      self.segments.push({from: null, to: null, s_date: null, e_date: null});
    };

    function getSeats(){
      var seats = {seatPreferences: []};
      angular.forEach(self.passengers, function(p, type){
        if (p.count > 0) {
          seats.seatPreferences.push({
            count: p.count,
            passengerType: type.toUpperCase()
          });
        }
      });
      return seats;
    };

    function getRoute(){
      var route = {segment: []};
      if (self.type == 'only') {
        var s = self.segments[0];
        route.segment.push({
          date: moment(s.s_date).format(),
          locationBegin: s.from,
          locationEnd: s.to
        });
        return route;
      }
      if (self.type == 'both') {
        var s = self.segments[0];
        route.segment.push({
          date: moment(s.s_date).format(),
          locationBegin: s.from,
          locationEnd: s.to
        });
        route.segment.push({
          date: moment(s.e_date).format(),
          locationBegin: s.to,
          locationEnd: s.from
        });
        return route;
      }
      if (self.type == 'complex') {
        angular.forEach(self.segments, function(s){
          route.segment.push({
            date: moment(s.s_date).format(),
            locationBegin: s.from,
            locationEnd: s.to
          });
        });
        return route;
      }
    };

    function getFlights(){
      var params = {
        eticketsOnly: self.etickets_only,
        mixedVendors: true,
        route: getRoute(),
        seats: getSeats(),
        serviceClass: self.service_class,
        skipConnected: self.skip_connected,
        type: self.type
      };

      FlightService.search_flights(params).then(function(res){
        if (res.flights.length == 0) {
          UfsBtsp.msg('По данному направлению отсутствуют перелеты на указанную дату')
          return false;
        }
        StoreService.set('flights_list', res);

        FlightSession.set('search', params);
        $state.go('flights.list');
      }).catch(PortBiletErrorService.handler);
    };

    self.search = function(){
      self.form.$submitted = true;
      if (!self.form.$valid) {
        return false;
      }

      getFlights();
    };
  }
]);