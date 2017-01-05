/**
  Provide a nice GUI for a pipe-delimited list in the site settings.

  @param settingValue is a reference to SiteSetting.value.
  @param choices is a reference to SiteSetting.choices
**/
export default Ember.TextField.extend({
  _select2FormatSelection: function(selectedObject, jqueryWrapper, htmlEscaper) {
    var text = selectedObject.text;
    if (text.length <= 6) {
      jqueryWrapper.closest('li.select2-search-choice').css({"border-bottom": '7px solid #'+text});
    }
    return htmlEscaper(text);
  },

  _seedSelect2Data: function(param, txtsrc){
    console.log("seed ", param);
    var chs = this.get(param).split("|") || [];
    var dta = [];

    chs.forEach(function(c) {
      var loc = I18n.t(txtsrc +'.'+ c);
      var txt = loc || c;
      dta.push({id: c, text: txt });
    });
    
    return dta;
  },


  _initializeSelect2: function(){  
    var self = this;
    
    var options = {
      multiple: true,
      separator: "|",
      tokenSeparators: ["|"],
      data : this._seedSelect2Data('choices', 'user.fixed_digest_deliveries'),
      width: 'off',
      dropdownCss: this.get("choices") ? {} : {display: 'none'},
      selectOnBlur: this.get("choices") ? false : true
    };

    var settingName = this.get('settingName');
    
    if (typeof settingName === 'string' && settingName.indexOf('colors') > -1) {
      options.formatSelection = this._select2FormatSelection;
    }
      console.log(options);


    this.$().select2(options).on("change", function(obj) {
      self.set("settingValue", obj.val.join("|"));
      self.refreshSortables();
    });
    
    this.$().select2("val", this.get("settingValue").split("|")).trigger("change");
    //this.refreshSortables();
    
  }.on('didInsertElement'),

  refreshOnReset: function() {
    this.$().select2("val", this.get("settingValue").split("|"));
  }.observes("settingValue"),

  refreshSortables: function() {
    var self = this;
    this.$("ul.select2-choices").sortable().on('sortupdate', function() {
      self.$().select2("onSortEnd");
    });
  }
});

