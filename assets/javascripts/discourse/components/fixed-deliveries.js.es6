import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed()
  deliveryChoices() {
    return ["0900","1000","1100","1200","1300","1400","1500","1600"]
  }
});